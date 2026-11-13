# Code samples: C++ component tests

What the code in this plan would look like. Part A is what a test author writes. Part B is the
support library underneath. Part C is what changes in the game.

**Status of these samples.** None has been compiled. Names that exist in the tree today are used
as they are: `OO_TEST`, `OO_CHECK`, `OO_CHECK_EQ`, `OO_TEST_MAIN`, `OOGUIScreenID::kIntro1`,
`OOEntityStatus::kInFlight`, `Universe::newShipWithName`, `OOShipRegistry::shipKeys`,
`GuiDisplayGen::getSelectedRow`, `SDL_PushEvent`, `SDL_GetKeyFromScancode`, and the script
expressions copied from `tests/component/steps/`. Everything under `oo::component`, and
`OOHeadlessOptions`, `startHeadless`, `tick`, `OOGameClock`, `OOGraphicsAvailable`,
`OOGameObserver` and `keyLookup`, is proposed here. Signatures may shift when the code meets the
compiler; the shape is what is being offered for approval.

---

## What `Game` is

`oo::component::Game` does not exist today. It is a **test class**, new in this feature, in
`tests/component-cpp/oo_component.hpp`. It is not part of the shipped game.

It wraps the game's real objects and hands them to the test: `game.universe()` is the real
`Universe*`, `game.player()` the real `PlayerEntity*`, and `game.add(...)` returns a handle to a
real `ShipEntity`. It adds what a test needs and the game does not have: starting with no window,
stepping time, pressing keys, and collecting events and errors.

It exists because a universe cannot yet be made by itself. `Universe::newUniverse` starts the
whole game (player, scripts, system) and only one can exist in a process. `Game` does that start
once. Spec 003 is the work that would let a test write `new Universe()` and add a player to it
directly.

---

## A. What a test looks like

### A0. The plain form: real objects, simulate, assert

The step style of A1 is the usual one (Jon, 2026-11-13: it is the more realistic). The plain
form is also available, for a test about one object. Jon's sketch of it:

```text
auto universe = new Universe();
addPlayerToUniverse(createPlayer());
addShipToUniverse(createEnemyAdder());

simulateUniverse(universe, ticks = 5minutes);

assertThat(player->isDead())
```

The same test as it would be written in this plan. Everything called on `universe`, `player` and
`adder` is a method the game has today.

```cpp
#include "oo_component.hpp"
#include "oo_test.hpp"

using namespace std::chrono_literals;
using oo::component::Game;
using oo::component::ShipWithKey;

OO_TEST(an_enemy_adder_kills_a_player_who_does_nothing) {
  Game game = Game::scenario(20260910);  // the universe and the player, in flight, nothing else
  Universe* universe = game.universe();
  PlayerEntity* player = game.player();

  // An Adder, 5 km off the player's nose, that has decided to attack.
  auto adder = game.add(ShipWithKey("adder").aheadOf(player, 5'000.0));
  OO_CHECK(adder.alive());
  adder->setPrimaryRole("pirate");
  adder->addTarget(player);
  adder->performAttack();

  game.simulate(5min);

  OO_CHECK(player->status() == OOEntityStatus::kDead);
  OO_CHECK(universe->getTime() >= 300.0);
  OO_COMPONENT_CHECK_NO_ERRORS(game);
}

OO_TEST_MAIN()
```

How each line of the sketch maps:

| Sketch | Here | Why it differs |
|---|---|---|
| `new Universe()` + `addPlayerToUniverse(createPlayer())` | `Game::scenario(seed)`, then `game.universe()` and `game.player()` | Today the universe creates its own player while it starts, and there can be one per process. |
| `addShipToUniverse(createEnemyAdder())` | `game.add(ShipWithKey("adder").aheadOf(player, 5'000.0))` | It is `universe->newShipWithName("adder")`, `setPosition`, `universe->addEntity`, in one call that returns the ship. |
| `simulateUniverse(universe, 5minutes)` | `game.simulate(5min)` | It also runs what the frame runs besides `Universe::update`: sound, frame callbacks, input. |
| `assertThat(player->isDead())` | `OO_CHECK(player->status() == OOEntityStatus::kDead)` | The game has no `isDead()`. The check macro is the harness's. |

Whether one Adder does kill an idle Cobra in five minutes is for the test to say. Nothing here
has been run.

A test that wants the sketch's helper can have it, in the test file:

```cpp
oo::component::ShipHandle AddEnemyAdder(Game& game, double metresAhead) {
  auto adder = game.add(ShipWithKey("adder").aheadOf(game.player(), metresAhead));
  adder->setPrimaryRole("pirate");
  adder->addTarget(game.player());
  adder->performAttack();
  return adder;
}
```

### A0.1. Basic tests: one ship, one behaviour

Small tests of one thing a ship does. Each creates what it needs, runs a short time and asserts
on the real objects. The game facts they rely on were read from the code on 2026-11-13 and are
given under each test; none has been run.
They share A0's includes and `using` lines. These four are deliverables (spec User Story 6), in
`test_laser_fires.cpp`, `test_ship_attacks.cpp`, `test_mining_laser.cpp` and `test_fire_key.cpp`.
Each program also takes `--without-weapon`, which skips the weapon mount so that the acceptance
check can see the test fail.

**A ship's gun fires and hits what is in front of it.**

```cpp
OO_TEST(a_ship_fires_its_forward_laser_and_hits_what_is_ahead) {
  Game game = Game::scenario(20260910);

  auto shooter = game.add(ShipWithKey("adder").near(game.player(), 20'000.0));
  shooter->setAITo("nullAI.plist");  // it sits still: this test is about the gun, not the pilot
  OO_CHECK(shooter->setWeaponMount(OOWeaponFacing::kForward, "EQ_WEAPON_PULSE_LASER"));

  auto target = game.add(ShipWithKey("asteroid").aheadOf(shooter, 1'000.0));
  const float energyBefore = target->energy;

  shooter->addTarget(target);
  OO_CHECK(shooter->fireMainWeapon(1'000.0));  // the game's own "fire the forward weapon"
  game.simulate(1s);

  OO_CHECK(shooter->laserHeatLevelForward() > 0.0f);                    // the gun was used
  OO_CHECK(target->energy < energyBefore);                              // the shot landed
  OO_CHECK(game.events().has("shipBeingAttacked", target));             // and the game said so
  OO_CHECK(game.events().has("shipAttackedOther", shooter));
  OO_COMPONENT_CHECK_NO_ERRORS(game);
}
```

**A ship told to attack opens fire by itself.** The same thing with the pilot in charge.

```cpp
OO_TEST(a_ship_told_to_attack_opens_fire) {
  Game game = Game::scenario(20260910);

  auto target = game.add(ShipWithKey("cobra3-trader").near(game.player(), 20'000.0));
  target->setAITo("nullAI.plist");
  auto hunter = game.add(ShipWithKey("adder").near(target, 5'000.0));
  OO_CHECK(hunter->setWeaponMount(OOWeaponFacing::kForward, "EQ_WEAPON_PULSE_LASER"));

  hunter->addTarget(target);
  hunter->performAttack();

  // It has to turn, close the range and line up, so give it time; assert that it happened.
  OO_CHECK(game.simulateUntil([&] { return game.events().has("shipBeingAttacked", target); }, 60s));
  OO_CHECK(target->energy < target->maxEnergy);
}
```

**A mining laser breaks an asteroid into boulders.**

```cpp
OO_TEST(a_mining_laser_breaks_an_asteroid_into_boulders) {
  Game game = Game::scenario(20260910);

  auto asteroid = game.add(ShipWithKey("asteroid").near(game.player(), 20'000.0));
  auto miner = game.add(ShipWithKey("adder").near(asteroid, 2'000.0));
  OO_CHECK(miner->setWeaponMount(OOWeaponFacing::kForward, "EQ_WEAPON_MINING_LASER"));
  OO_CHECK_EQ(game.shipsWithRole("boulder").size(), 0u);

  miner->addTarget(asteroid);
  miner->performMining();
  OO_CHECK(miner->isMining());

  OO_CHECK(game.simulateUntil([&] { return !asteroid.alive(); }, 2min));

  // A mined asteroid always leaves at least two boulders. One destroyed any other way leaves
  // them only one time in five.
  OO_CHECK(game.shipsWithRole("boulder").size() >= 2u);
  OO_CHECK(game.events().has("shipDied", asteroid));
  OO_COMPONENT_CHECK_NO_ERRORS(game);
}
```

The game facts: `isMining()` is true for a ship in the mining behaviour with a mining laser
forward. A rock that dies while being mined throws out `2 + random(0..likely_cargo)` rocks of its
debris role, which for an asteroid is `boulder`.

**The player fires with the fire key.** The same gun test, from the keyboard.

```cpp
OO_TEST(the_fire_key_fires_the_players_laser) {
  Game game = Game::inFlightWithKeys(20260910);  // a scenario game that also takes key presses
  PlayerEntity* player = game.player();
  OO_CHECK(player->setWeaponMount(OOWeaponFacing::kForward, "EQ_WEAPON_PULSE_LASER"));

  auto target = game.add(ShipWithKey("asteroid").aheadOf(player, 1'000.0));
  const float energyBefore = target->energy;

  // "a" is the default fire key (key_fire_lasers). Held until the shot lands.
  OO_CHECK(game.hold("a", [&] { return target->energy < energyBefore; }, 5s));
  OO_CHECK(player->laserHeatLevelForward() > 0.0f);
}
```

**What `auto` is here.** `game.add` returns an `oo::component::ShipHandle`, not a bare pointer.
`handle->` calls the real `ShipEntity`, and a handle can be passed wherever the game takes a
`ShipEntity*`. `handle.alive()` says whether the ship is still in the universe. The handle does
not keep the ship alive: if a test held an owning pointer, the game's own "my target is gone"
checks would see a ship that never goes away, and the test would change what it is testing.

### A0.2. Keys operate the ship

Tests that press keys and check that the ship did the right thing, once. Deliverables (spec User
Story 3, scenarios 8 to 10), in `test_launch_key.cpp` and `test_remapped_key.cpp`. The fire-key
test in A0.1 belongs with them.

**The launch key launches once.** An early build of the C++ port had a fault where pressing `1`
again after launching kept replaying the launch animation. How that fault worked is not recorded,
so the test asserts the symptom both ways it could arise: the key held down right through the
launch, and the key pressed again afterwards.

```cpp
OO_TEST(the_launch_key_launches_once) {
  Game game = Game::docked(20260910);  // a new commander, docked at the main station
  PlayerEntity* player = game.player();
  Universe* universe = game.universe();
  OO_CHECK(player->isDocked());

  // "1" is the launch key while docked (key_launch_ship). Keep it held until the launch is over:
  // a held key is one press, however many frames it is down for.
  OO_CHECK(game.hold("1",
                     [&] {
                       return player->status() == OOEntityStatus::kInFlight &&
                              universe->breakPatternOver();
                     },
                     30s));
  OO_CHECK(!player->isDocked());
  OO_CHECK(universe->viewDirection == OOViewID::kForward);
  OO_CHECK_EQ(game.events().count("shipWillLaunchFromStation"), 1u);
  OO_CHECK_EQ(game.events().count("shipLaunchedFromStation"), 1u);

  // In flight the same key is "forward view" (key_view_forward). Pressing it must not launch
  // again, and must not bring the launch tunnel back.
  game.press("1");
  game.simulate(5s);

  OO_CHECK(player->status() == OOEntityStatus::kInFlight);
  OO_CHECK(universe->breakPatternOver());
  OO_CHECK(universe->viewDirection == OOViewID::kForward);
  OO_CHECK_EQ(game.events().count("shipWillLaunchFromStation"), 1u);
  OO_CHECK_EQ(game.events().count("shipLaunchedFromStation"), 1u);
  OO_COMPONENT_CHECK_NO_ERRORS(game);
}
```

The game facts: docked, the launch key calls `handleUndockControl()` and then
`launchFromStation()`. The launch raises `shipWillLaunchFromStation` and
`shipLaunchedFromStation`. `Universe::breakPatternOver()` is true when no launch-tunnel rings are
left.

**A remapped key does its new job, and the old key does nothing.**

```cpp
OO_TEST(a_remapped_fire_key_fires_and_the_old_key_does_not) {
  // Fire moved from "a" to "k", stored the way the keyboard settings screen stores it.
  Game game = Game::inFlightWithKeys(20260910, Settings().remapKey("key_fire_lasers", "k"));
  PlayerEntity* player = game.player();
  OO_CHECK(player->setWeaponMount(OOWeaponFacing::kForward, "EQ_WEAPON_PULSE_LASER"));

  auto target = game.add(ShipWithKey("asteroid").aheadOf(player, 1'000.0));
  const float energyBefore = target->energy;

  // The old key no longer fires.
  OO_CHECK(!game.hold("a", [&] { return target->energy < energyBefore; }, 2s));
  OO_CHECK_EQ(player->laserHeatLevelForward(), 0.0f);

  // The new key does.
  OO_CHECK(game.hold("k", [&] { return target->energy < energyBefore; }, 5s));
  OO_CHECK(player->laserHeatLevelForward() > 0.0f);
}
```

`Settings` describes the player's saved settings before the game starts. `remapKey` writes one
entry into `KeyConfigOverrides` in the test's private settings file, in the form
`PlayerEntity::saveKeySetting` writes, which is where the game reads remapped keys from at
start-up. The key `k` is a placeholder: the implementation picks a key no control uses by default.

**The Flatpak `n` report.** The test thought out for it is A5 (the tutorial advanced by `n`, on
every platform, under three layouts, and inside the Flatpak build) together with A6 (one case per
suspected cause: Caps Lock on, a non-Latin layout, a stray modifier, keys that alias). The
investigation itself is milestone M7.

### A1. A ported scenario (User Story 1)

The usual style. A port keeps its original's steps and script expressions, so it reads as the
feature file does. The windowed original, `tests/component/features/s1_police_kills_pirate.feature`:

```gherkin
Scenario: A police viper engages a lone pirate
  Given a universe seeded with 20260910
  When I spawn 1 ship with role "police"
  And I spawn 1 ship with role "pirate" within 10 km
  Then within 900 ticks a ship with role "police" engages a ship with role "pirate"
  And a ship with role "police" survives
```

Its C++ counterpart, `tests/component-cpp/test_s1_police_kills_pirate.cpp`:

```cpp
// The headless counterpart of features/s1_police_kills_pirate.feature: same seed, same spawns,
// same assertions. Each line below is one line of the feature.

#include "oo_component.hpp"
#include "oo_test.hpp"

using namespace std::chrono_literals;
using oo::component::Game;
using oo::component::ShipsWithRole;
using oo::component::ticks;

OO_TEST(a_police_viper_engages_a_lone_pirate) {
  // Given a universe seeded with 20260910
  Game game = Game::scenario(20260910);

  // When I spawn 1 ship with role "police"
  OO_CHECK_EQ(game.spawn(ShipsWithRole("police").count(1)).size(), 1u);
  // And I spawn 1 ship with role "pirate" within 10 km
  OO_CHECK_EQ(game.spawn(ShipsWithRole("pirate").count(1).withinKm(10)).size(), 1u);

  // Then within 900 ticks a ship with role "police" engages a ship with role "pirate"
  OO_CHECK(game.simulateUntil([&] { return game.engages("police", "pirate"); }, ticks(900)));
  // And a ship with role "police" survives
  OO_CHECK(game.countWithRole("police") > 0);

  OO_COMPONENT_CHECK_NO_ERRORS(game);
}

OO_TEST_MAIN()
```

What it prints when the engagement never happens:

```text
FAIL tests/component-cpp/test_s1_police_kills_pirate.cpp:22 [a_police_viper_engages_a_lone_pirate]: game.simulateUntil([&] { return game.engages("police", "pirate"); }, ticks(900))
  seed 20260910, game time 112.500 s, screen kMain
  last events:
    17.117 shipEvent  shipSpawned         viper#412
    17.117 shipEvent  shipSpawned         pirate-cobra3#413
    ...
  rerun: tests/run.sh component --cpp -k s1_police_kills_pirate
FAIL a_police_viper_engages_a_lone_pirate
oo_test: tests/component-cpp/test_s1_police_kills_pirate.cpp: 1 tests, 5 checks, 1 failures
```

### A2. A scenario that asserts order of events

Something the windowed tier cannot do, because it can only poll:

```cpp
OO_TEST(a_destroyed_ship_dies_before_it_leaves_the_ship_list) {
  Game game = Game::scenario(20260910);
  auto pirate = game.spawn(ShipsWithRole("pirate")).front();
  const auto id = pirate->universalID;

  game.eval("system.allShips.filter(function(s){ return s.primaryRole == 'pirate'; })[0]"
            ".explode()");
  game.simulate(2s);

  const auto died = game.events().firstOf("shipDied", id);
  OO_CHECK(died.has_value());
  OO_CHECK_EQ(game.countWithRole("pirate"), 0);
  OO_CHECK_EQ(game.presentation().framesRequested, 120);  // 2 s at 60 steps a second
}
```

### A3. The census, used as a test (User Story 2)

The census is a program, not a test file a developer edits. This is its core, in
`tests/component-cpp/component_census.cpp`:

```cpp
// One ship definition: spawn it, run it, check it, remove it. The result must not depend on which
// definitions were tried before, so the generators are reseeded from the base seed and the key.
Outcome TryShip(Game& game, const std::string& key, std::uint32_t baseSeed) {
  game.reseed(SeedFor(baseSeed, key));
  const std::size_t entitiesBefore = game.entityCount();
  const std::size_t mark = game.events().size();

  std::shared_ptr<ShipEntity> ship = game.spawnKey(key, game.pointNearPlayer(10'000.0));
  if (ship == nullptr) {
    return Outcome::failed(key, "spawn returned null", game.errorsSince(mark));
  }

  game.simulate(10s);

  if (!game.contains(ship.get())) {
    return Outcome::left(key, game.time());  // the expectations file says whether that is allowed
  }
  if (ship->subEntityCount() != DeclaredSubentityCount(key)) {
    return Outcome::failed(key, "sub-part count differs from the definition");
  }
  if (auto errors = game.errorsSince(mark); !errors.empty()) {
    return Outcome::failed(key, errors.front().text);
  }

  game.remove(ship.get());
  ship.reset();
  game.step();
  if (game.entityCount() != entitiesBefore) {
    return Outcome::uncleanFailure(key);  // the child process ends after this one
  }
  return Outcome::passed(key);
}
```

and the loop that guarantees nobody is left out:

```cpp
// Every top-level key of the merged core shipdata gets exactly one row.
for (const Definition& def : ListShipDefinitions()) {  // read from the data, not from a list here
  NoteProgress(progressFile, def);                     // flushed: the parent reads it after a crash
  switch (def.cls) {
    case Class::kTemplate: report.add(Outcome::notApplicable(def.key, "template")); break;
    case Class::kPart:     parts.push_back(def);        break;  // decided once parents are known
    case Class::kCandidate: report.add(TryShip(game, def.key, seed)); break;
  }
}
```

A census failure reads like this:

```text
FAIL ship  thargoid-mothership   left the universe unclean: 3 entities remain after removal
FAIL equip EQ_CLOAKING_DEVICE    script.javaScript.exception.TypeError: this.ship is null
component_census: 194 ships, 41 equipment: 108 passed, 4 left, 85 not-applicable, 2 failed, 0 expected
```

(The two failures above are invented to show the format.)

### A4. Menus (User Story 3)

`tests/component-cpp/test_menus.cpp`:

```cpp
#include "oo_component.hpp"
#include "oo_test.hpp"

using oo::component::Game;

namespace {

struct StartEntry {
  const char* text;        // what the row says
  OOGUIScreenID opens;     // the screen Enter leads to
  const char* back;        // the key that returns to the start screen
};

// Filled in from the game at implementation time; shown here as read from the code today.
const StartEntry kStartEntries[] = {
    {"Start New Commander", OOGUIScreenID::kNewGame, "escape"},
    {"Load Commander", OOGUIScreenID::kLoad, "escape"},
    {"View Ship Library", OOGUIScreenID::kShipLibrary, "escape"},
    {"Game Options", OOGUIScreenID::kGameOptions, "escape"},
    {"Manage Expansion Packs", OOGUIScreenID::kOXZManager, "escape"},
};

}  // namespace

OO_TEST(the_selection_moves_one_row_per_press) {
  Game game = Game::atStartScreen(20260910);
  OO_CHECK(game.screen() == OOGUIScreenID::kIntro1);

  const int first = game.selectedRow();
  OO_COMPONENT_PRESS_EXPECT(game, "down", game.selectedRow() == first + 1);
  OO_COMPONENT_PRESS_EXPECT(game, "up", game.selectedRow() == first);
}

OO_TEST(every_start_screen_entry_opens_and_returns) {
  Game game = Game::current();  // one game per program; the cases share it

  // The table must cover the menu, not the other way round: count the game's own rows.
  OO_CHECK_EQ(game.selectableRowCount(), std::size(kStartEntries) + 1);  // + Exit Game

  for (const StartEntry& entry : kStartEntries) {
    game.selectRowWithText(entry.text);
    OO_COMPONENT_PRESS_EXPECT(game, "enter", game.screen() == entry.opens);
    OO_COMPONENT_PRESS_EXPECT(game, entry.back, game.screen() == OOGUIScreenID::kIntro1);
  }
  OO_COMPONENT_CHECK_NO_ERRORS(game);
}

OO_TEST(exit_game_asks_to_quit) {
  Game game = Game::current();
  game.selectRowWithText("Exit Game");
  OO_COMPONENT_PRESS_EXPECT(game, "enter", game.exitRequested());
}

OO_TEST_MAIN()
```

### A5. The tutorial by `n`, under a keyboard layout (User Story 3)

`tests/component-cpp/test_tutorial_keys.cpp`. The meson file registers it three times, with
`--layout us`, `--layout fr_azerty` and `--layout ru`.

```cpp
#include "oo_component.hpp"
#include "oo_test.hpp"
#include "tutorial_steps.hpp"  // StartTutorial(), Progress(), Stage

using oo::component::Game;

OO_TEST(n_advances_every_step_of_lessons_0_and_1) {
  Game game = Game::atStartScreen(20260910);
  game.useLayout(oo::component::layoutFromArguments());

  // Start New Commander -> scenario screen -> Tutorial -> mission screen -> launch.
  StartTutorial(game);
  OO_CHECK(Progress(game) == (Stage{0, 2}));  // the first "press n"

  int presses = 0;
  while (Progress(game) < (Stage{2, 0}) && presses++ < 80) {
    const Stage before = Progress(game);
    // Held until the tutorial moves, as the windowed walkthrough holds it. The control latches,
    // so one press advances one step however long the key stays down.
    OO_COMPONENT_PRESS_EXPECT(game, "n", Progress(game) != before);
  }
  OO_CHECK(Progress(game) == (Stage{2, 0}));
  OO_COMPONENT_CHECK_NO_ERRORS(game);
}

OO_TEST_MAIN()
```

`tutorial_steps.hpp` reads the tutorial's progress with the expression the windowed test uses
(`tests/component/steps/tutorial_steps.py`, `PROGRESS_JS`):

```cpp
struct Stage {
  int stage = 0;
  int substage = 0;
  auto operator<=>(const Stage&) const = default;
};

inline Stage Progress(oo::component::Game& game) {
  const std::string text = game.evalString(
      "(function(){ var t = worldScripts[\"oolite-tutorial\"];"
      " return t.$tutorialStage + ' ' + t.$tutorialSubstage; })()");
  Stage s;
  std::sscanf(text.c_str(), "%d %d", &s.stage, &s.substage);
  return s;
}

inline void StartTutorial(oo::component::Game& game) {
  game.selectRowWithText("Start New Commander");
  OO_COMPONENT_PRESS_EXPECT(game, "enter", game.screen() == OOGUIScreenID::kNewGame);
  game.selectRowWithText("Tutorial");
  OO_COMPONENT_PRESS_EXPECT(game, "enter", game.screen() == OOGUIScreenID::kMission);
  OO_COMPONENT_PRESS_EXPECT(game, "enter", game.screen() != OOGUIScreenID::kMission);
  OO_CHECK(game.simulateUntil(
      [&] {
        return game.player()->status() == OOEntityStatus::kInFlight &&
               game.screen() == OOGUIScreenID::kMain;
      },
      60s));
}
```

When a key does nothing, the message is the one SC-007 asks for:

```text
FAIL tests/component-cpp/test_tutorial_keys.cpp:21 [n_advances_every_step_of_lessons_0_and_1]: pressing n had no effect
  layout ru: n -> scancode 17 (N), no modifiers -> key 0x442
  seed 20260910, game time 31.350 s, screen kMain, tutorial at lesson 0 step 2
  rerun: tests/run.sh component --cpp -k tutorial_keys_ru
```

### A6. A key-fault case (User Story 4)

`tests/component-cpp/test_key_faults.cpp`. Each case says what a player should see. If the
observation in research.md is right, the case fails today, and that failure is the finding.

```cpp
// H1: with Caps Lock on, the n key should still advance the tutorial.
OO_TEST(n_works_with_caps_lock_on) {
  Game game = Game::atStartScreen(20260910);
  StartTutorial(game);
  const Stage before = Progress(game);

  game.pressScancode(SDL_SCANCODE_N, SDL_KMOD_CAPS);  // by physical key: no layout involved
  game.simulate(1s);

  OO_CHECK(Progress(game) != before);
}

// H4: Caps Lock itself must not arrive as some other key.
OO_TEST(caps_lock_is_not_seen_as_the_9_key) {
  Game game = Game::current();
  game.keyDownScancode(SDL_SCANCODE_CAPSLOCK, SDL_KMOD_CAPS);
  game.step(2);
  OO_CHECK(!game.view()->isDown('9'));
  game.keyUpScancode(SDL_SCANCODE_CAPSLOCK, SDL_KMOD_NONE);
}

// H5: every physical key can be pressed. Under the sanitizer build an out-of-range write fails
// this case by itself.
OO_TEST(every_scancode_can_be_pressed_and_released) {
  Game game = Game::current();
  for (int code = 1; code < SDL_SCANCODE_COUNT; ++code) {
    game.keyDownScancode(static_cast<SDL_Scancode>(code), SDL_KMOD_NONE);
    game.step();
    game.keyUpScancode(static_cast<SDL_Scancode>(code), SDL_KMOD_NONE);
    game.step();
  }
  OO_COMPONENT_CHECK_NO_ERRORS(game);
}
```

---

## B. The support library (`tests/component-cpp/oo_component.hpp`)

### B1. The interface

```cpp
namespace oo::component {

// The windowed tier's "tick" is one AI think interval, 0.125 s (tests/component/README.md).
using GameTime = std::chrono::duration<double>;  // so a test can write 5min, 10s, 250ms
constexpr GameTime ticks(int n) { return GameTime{n * 0.125}; }

// What to spawn, said fluently and passed to one call. There is no build() or go(): the call that
// takes it does the work.
//   game.spawn(ShipsWithRole("pirate").count(2).withinKm(10))
//   game.add(ShipWithKey("adder").aheadOf(player, 5'000.0))
// The required value is the constructor's argument. Everything else is optional, in any order.
// Each setter returns a copy, so a half-built description can be kept and reused safely.
class ShipsWithRole {
 public:
  explicit ShipsWithRole(std::string_view role) : role_(role) {}  // "police", "pirate", ...
  ShipsWithRole count(int n) const { auto next = *this; next.count_ = n; return next; }
  // Of the first ship spawned. Unset: around the player.
  ShipsWithRole withinKm(int km) const { auto next = *this; next.withinKm_ = km; return next; }

 private:
  friend class Game;
  std::string_view role_;
  int count_ = 1;
  std::optional<int> withinKm_;
};

class ShipWithKey {
 public:
  explicit ShipWithKey(std::string_view shipKey) : key_(shipKey) {}  // "adder", "cobra3-trader"
  ShipWithKey at(HPVector position) const;
  ShipWithKey aheadOf(Entity* entity, double metres) const;  // on that entity's nose
  ShipWithKey near(Entity* entity, double metres) const;     // anywhere within that distance

 private:
  friend class Game;
  std::string_view key_;
  // ... the placement chosen; default: near the player
};

// The player's saved settings, described before the game starts.
//   Settings().remapKey("key_fire_lasers", "k")
class Settings {
 public:
  // One entry in KeyConfigOverrides, as the keyboard settings screen saves it.
  Settings remapKey(std::string_view control, std::string_view key) const;
  Settings keyboardCode(std::string_view code) const;  // "default", "gbr", "deu", ...
};

// A ship a test added. Use it like a ShipEntity*; ask alive() before using it after the ship
// could have died. It does not keep the ship alive: inside it is a std::weak_ptr<ShipEntity>.
class ShipHandle {
 public:
  bool alive() const;                 // still in the universe
  OOUniversalID id() const;           // kept after the ship is gone, so events can still be matched
  ShipEntity* operator->() const;     // fails the test, by name, if the ship is gone
  operator ShipEntity*() const;       // null if the ship is gone
};

class Game {
 public:
  // One per process. A second call fails the test.
  static Game scenario(std::uint32_t seed);        // empty system, player in flight, no keys
  static Game inFlightWithKeys(std::uint32_t seed, const Settings& settings = {});  // + keys
  static Game docked(std::uint32_t seed, const Settings& settings = {});  // new commander, docked
  static Game atStartScreen(std::uint32_t seed);   // a normal start, with a windowless view
  static Game current();                           // the game an earlier case created

  // Time. Nothing here waits on the real clock.
  void step(int steps = 1);                        // each step is 1/60 s
  void simulate(GameTime span);                    // game.simulate(5min)
  bool simulateUntil(const std::function<bool()>& done, GameTime atMost);
  double time() const;

  // The world, in the vocabulary of tests/component/steps/world_steps.py.
  std::vector<ShipHandle> spawn(const ShipsWithRole& what);  // the ships it added
  int countWithRole(std::string_view role);
  bool engages(std::string_view hunter, std::string_view quarry);

  // The world, directly: the game's own objects.
  Universe* universe();    // not owned: the game keeps both for the whole process,
  PlayerEntity* player();  // as PlayerEntity::sharedPlayer() hands the player out today
  ShipHandle add(const ShipWithKey& what);  // not alive() if it could not be made
  std::shared_ptr<ShipEntity> spawnKey(const std::string& shipKey, HPVector position);
  std::vector<ShipHandle> shipsWithRole(std::string_view role);
  void remove(ShipEntity* ship);
  std::size_t entityCount() const;

  // Script expressions, evaluated the way the debug console evaluates them.
  double eval(std::string_view js);
  bool evalBool(std::string_view js);
  std::string evalString(std::string_view js);

  // What happened.
  const EventRecord& events() const;
  std::vector<Event> errors() const;
  std::vector<Event> errorsSince(std::size_t mark) const;
  const PresentationRecord& presentation() const;
  std::uint64_t digest() const;

  // Keys and screens (atStartScreen games only).
  void useLayout(std::string_view name);           // tests/component-cpp/layouts/<name>.tsv
  void press(std::string_view key);                // "n", "enter", "escape", "down", "f5"
  bool hold(std::string_view key, const std::function<bool()>& until, GameTime atMost);
  void pressScancode(SDL_Scancode code, SDL_Keymod mods);
  void keyDownScancode(SDL_Scancode code, SDL_Keymod mods);
  void keyUpScancode(SDL_Scancode code, SDL_Keymod mods);
  OOGUIScreenID screen();
  int selectedRow();
  std::string rowText(int row);
  void selectRowWithText(std::string_view text);
  bool exitRequested() const;
};

}  // namespace oo::component

// Press a key and require an effect. Fails with "pressing <key> had no effect", the layout's
// translation of the key, the screen and the game time.
#define OO_COMPONENT_PRESS_EXPECT(game, key, effect) \
  ::oo::component::pressExpect((game), (key), [&] { return (effect); }, #effect, __FILE__, __LINE__)

#define OO_COMPONENT_CHECK_NO_ERRORS(game) \
  ::oo::component::checkNoErrors((game), __FILE__, __LINE__)
```

### B2. A step helper keeps the windowed step's meaning

`spawn` runs the same script the Python step runs (`world_steps.py`, `_spawn`): the role's pinned
ship key, the primary role set back to the scenario's role, the pirate's bounty, the role's AI.

```cpp
std::vector<ShipHandle> Game::spawn(const ShipsWithRole& what) {
  const std::string_view role = what.role_;
  const int count = what.count_;
  // "within N km" measures from the first ship spawned; otherwise spawn around the player.
  const HPVector at = what.withinKm_ && locus_ ? *locus_ : player()->getPosition();
  const double radiusMetres = what.withinKm_ ? *what.withinKm_ * 1000.0 : kSpawnRadiusMetres;

  const std::string selector = PinnedShipKeyFor(role);  // "[viper]" for "police", as ROLE_SHIP_KEY
  const std::string js = std::format(
      "(function(){{"
      " var added = system.addShips({0}, {1}, [{2}, {3}, {4}], {5});"
      " if (!added) return 0;"
      " for (var i = 0; i < added.length; i++) {{"
      "   added[i].primaryRole = {6};"
      "   {7}"
      " }}"
      " return added.length; }})()",
      JsString(selector), count, at.x, at.y, at.z, radiusMetres, JsString(role),
      PerRoleSetup(role));  // bounty for pirates, setAI(...) where ROLE_AI has an entry
  const int added = static_cast<int>(eval(js));
  std::vector<ShipHandle> ships = NewestShipsWithRole(role, added);
  if (!ships.empty() && !locus_) locus_ = ships.front()->getPosition();
  return ships;
}

bool Game::engages(std::string_view hunter, std::string_view quarry) {
  // The expression of the windowed step "a ship with role H engages a ship with role Q".
  return evalBool(std::format(
      "(function(){{ var r = 0;"
      " system.allShips.forEach(function(s){{"
      "   if (s.primaryRole == {0} && s.hasHostileTarget"
      "       && s.target && s.target.primaryRole == {1}) r = 1;"
      " }});"
      " return r; }})()",
      JsString(hunter), JsString(quarry)));
}
```

### B3. Stepping and pressing

```cpp
void Game::step(int steps) {
  for (int i = 0; i < steps; ++i) {
    if (view_ != nullptr) view_->pollControls();  // the real input loop, draining SDL's queue
    controller_->tick(kStep);                     // 1/60 s; advances the game clock, never sleeps
    if (digestOut_) WriteDigest();
  }
}

bool Game::simulateUntil(const std::function<bool()>& done, GameTime atMost) {
  const double deadline = time() + atMost.count();
  while (time() < deadline) {
    if (done()) return true;
    step();
  }
  return done();
}

// A key press is two events on SDL's own queue. Nothing in the game's key path is bypassed.
void Game::keyDownScancode(SDL_Scancode code, SDL_Keymod mods) {
  SDL_Event event{};
  event.type = SDL_EVENT_KEY_DOWN;
  event.key.scancode = code;
  event.key.mod = mods;
  event.key.key = SDL_GetKeyFromScancode(code, mods, true);  // what a real event carries
  event.key.down = true;
  SDL_PushEvent(&event);
}

void Game::press(std::string_view key) {
  const KeyStroke stroke = layout_.strokeFor(key);  // "n" on fr_azerty: SDL_SCANCODE_N, no mods
  keyDownScancode(stroke.scancode, stroke.mods);
  step(2);                                          // sampled once per frame; let it be seen down
  keyUpScancode(stroke.scancode, SDL_KMOD_NONE);
  step(2);                                          // and seen up, or the next press is a repeat
}
```

---

## C. What changes in the game

### C1. The options (`src/Core/OOHeadless.h`)

```cpp
// How a game is started. A default-constructed value is the windowed game, exactly as today.
struct OOHeadlessOptions {
  enum class AddOns { kAll, kNone };

  bool headless = false;                    // no window, no GL, no sound device
  std::optional<std::uint32_t> seed;        // every generator; unset = clock or OO_RANDOM_SEED
  AddOns addOns = AddOns::kAll;             // kNone: built-in Resources only
  bool populate = true;                     // fill the system with traffic
  bool startInFlight = false;               // put the player in flight in the empty system
  bool inputView = false;                   // a view with no window, so keys can be delivered
  OOTimeDelta step = 1.0 / 60.0;            // the stepper's fixed dt
  OOTimeDelta scriptTimeLimit = 0.0;        // 0 = the engine's own limit
};

// False in a headless game. No gl* function may be called while it is false.
bool OOGraphicsAvailable();
```

### C2. The frame, split (`src/Core/GameController.cpp`)

Today:

```cpp
void GameController::doPerformGameTick() {
  try {
    if (gameIsPaused)
      delta_t = 0.0;  // no movement!
    else {
      delta_t = oo::date::monotonicSeconds() - last_timeInterval;
      last_timeInterval += delta_t;
      if (delta_t > MINIMUM_GAME_TICK) delta_t = MINIMUM_GAME_TICK;
    }

    if (UNIVERSE != nullptr) UNIVERSE->update(delta_t);
    if (EXPECT_NOT((PLAYER != nullptr ? PLAYER->status() : OOEntityStatus{}) ==
                   OOEntityStatus::kRestartGame)) {
      if (UNIVERSE != nullptr) UNIVERSE->reinitAndShowDemo(true);
    }
    ::OOSound::update();
    if (!gameIsPaused) {
      OOJSFrameCallbacksInvoke(delta_t);
    }
  } catch (const oo::Exception& exception) {
    OO_LOG("exception.backtrace", "{} : {}", exception.name(), exception.reason());
  }
  // ... then draw
}
```

After. The body moves, unchanged, into `tick`. The windowed loop still measures and still draws:

```cpp
// One simulation step. The windowed frame calls this with the dt it measured; a headless game
// calls it with a fixed dt. It reads no clock and does not draw.
void GameController::tick(OOTimeDelta dt) {
  _clock.advance(dt);  // does nothing for the system clock
  if (UNIVERSE != nullptr) UNIVERSE->update(dt);
  if (EXPECT_NOT((PLAYER != nullptr ? PLAYER->status() : OOEntityStatus{}) ==
                 OOEntityStatus::kRestartGame)) {
    if (UNIVERSE != nullptr) UNIVERSE->reinitAndShowDemo(true);
  }
  ::OOSound::update();
  if (!gameIsPaused) {
    OOJSFrameCallbacksInvoke(dt);
  }
}

void GameController::doPerformGameTick() {
  try {
    if (gameIsPaused)
      delta_t = 0.0;  // no movement!
    else {
      delta_t = _clock.monotonicSeconds() - last_timeInterval;
      last_timeInterval += delta_t;
      if (delta_t > MINIMUM_GAME_TICK) delta_t = MINIMUM_GAME_TICK;
    }
    tick(delta_t);
  } catch (const oo::Exception& exception) {
    OO_LOG("exception.backtrace", "{} : {}", exception.name(), exception.reason());
  }
  // ... then draw, as before
}
```

### C3. Starting without a window

```cpp
// The start-up of applicationDidFinishLaunching without the splash, the display modes, the
// expansion manager, the window and the frame loop.
void GameController::startHeadless(const OOHeadlessOptions& options) {
  if (!options.headless || !options.seed) {
    OORaiseException(OOInvalidArgumentException, "%s: needs headless and a seed",
                     __PRETTY_FUNCTION__);
  }
  _options = options;
  _clock = OOGameClock::manual(*options.seed);
  ranrot_srand(*options.seed);

  if (options.inputView) {
    _gameView = oo::makeShared<MyOpenGLView>();
    _gameView->initHeadless(this);  // SDL events + the dummy video driver; no window, no audio
  }

  Universe::newUniverse(_gameView.get(), options);  // the same call the windowed start makes
  loadPlayerIfRequired();
  if (options.startInFlight) PLAYER->enterFlightForHeadless();
}
```

### C4. A guarded GL site (`src/Core/Entities/OOSunEntity.cpp`)

```cpp
void OOSunEntity::setSunColor(OOColor sun_color) {
  // ... the colour arithmetic, unchanged: it sets members the simulation reads ...

  if (!OOGraphicsAvailable()) return;  // headless: nothing to tell the GL about
  OOGL(glLightfv(GL_LIGHT1, GL_AMBIENT, sun_ambient));
  OOGL(glLightfv(GL_LIGHT1, GL_DIFFUSE, sun_diffuse));
  OOGL(glLightfv(GL_LIGHT1, GL_SPECULAR, sun_specular));
}
```

The rule for every such site: the guard goes around the GL calls only. Anything that computes a
value the simulation reads stays above it.

### C5. What catches a missed site (`gl_trap.cpp`, generated)

Linked into the C++ component tests on Linux and macOS. One function per GL symbol the game's
objects import:

```cpp
// Generated by tests/component-cpp/gl_trap_gen.py from the game's objects. Do not edit.
#include <cstdio>
#include <cstdlib>

namespace {
[[noreturn]] void Trap(const char* name) {
  std::fprintf(stderr, "GL call %s while headless\n", name);
  std::fflush(stderr);
  std::abort();
}
}  // namespace

extern "C" {
void glLightfv() { Trap("glLightfv"); }
void glGetString() { Trap("glGetString"); }
void glGenFramebuffers() { Trap("glGenFramebuffers"); }
// ... about 200 more
}
```

### C6. The key lookup (`src/SDL/MyOpenGLView+Input.cpp`)

Today:

```cpp
      case SDL_EVENT_KEY_DOWN:
        kbd_event = reinterpret_cast<SDL_KeyboardEvent*>(&event);
        key_id =
            SDL_GetKeyFromScancode(kbd_event->scancode, kbd_event->mod, false);
```

After. One line changes, and the default does what the line did:

```cpp
      case SDL_EVENT_KEY_DOWN:
        kbd_event = reinterpret_cast<SDL_KeyboardEvent*>(&event);
        key_id = keyLookup(kbd_event->scancode, kbd_event->mod);
```

```cpp
// MyOpenGLView.h
  // What key a physical key gives. SDL's answer for the active layout, unless a test has
  // installed a recorded layout.
  std::function<SDL_Keycode(SDL_Scancode, SDL_Keymod)> keyLookup =
      [](SDL_Scancode scancode, SDL_Keymod mod) {
        return SDL_GetKeyFromScancode(scancode, mod, false);
      };
```

### C7. The observer (`src/Core/Entities/ShipEntity.cpp`)

```cpp
void ShipEntity::doScriptEvent(/* ... as today ... */) {
  if (OOGameObserver* observer = GameController::sharedController()->observer()) {
    observer->shipEvent(UNIVERSE->getTime(), this, message);  // null in the windowed game
  }
  // ... dispatch to the scripts, unchanged ...
}
```

### C8. A recorded layout (`tests/component-cpp/layouts/fr_azerty.tsv`)

```text
# French AZERTY. Recorded with SDL 3.4.8 on <system>, by printing
# SDL_GetKeyFromScancode(scancode, mods, false) for every scancode.
# scancode  mods    keycode   comment
4           -       0x71      q   (the key marked A on a US board)
4           shift   0x51      Q
17          -       0x6e      n
17          shift   0x4e      N
17          caps    0x4e      N
30          -       0x26      &   (the 1 key: digits need shift)
30          shift   0x31      1
```
