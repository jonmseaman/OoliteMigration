# Contract: headless scenario test support

Test-only support code in `oolite-dev/tests/unit/scenario/`: `oo_scenario.hpp` and its `.cpp`,
built on `OOGame`'s public interface. The production interface stays small: what a test needs
that the game does not belongs here, not in `src/`.

```cpp
struct OOScenarioOptions {
  uint64_t seed = 20260910;
  std::string system = "Lave";           // the system to start in (galaxy 0)
  OOTimeDelta tickSeconds = 1.0 / 60;    // the fixed step (research R6)
};

class OOScenario {
 public:
  explicit OOScenario(OOScenarioOptions options = {});
  ~OOScenario();                          // destroys the game, then its context
  // Builds its own OOGameContext with headless options and stand-ins, an OOGame on it, a
  // universe from OOUniverseOptions{NONE, populate=false, detail=minimum}, and the player in
  // flight at the origin. Holds no scope: every method below opens an OOGameContextScope for
  // its own context for the length of the call, so two scenarios can be driven in turn on one
  // thread.

  // Spawning. Entities are owned by the universe; the test observes them.
  std::weak_ptr<ShipEntity> spawn(std::string_view role, Vector position);
  std::weak_ptr<ShipEntity> spawnShip(std::string_view shipKey, Vector position);  // a pinned key
  void spawnAsteroidField(Vector centre, unsigned count, double radius);
  PlayerEntity& player();

  // Time
  void step(unsigned ticks = 1);
  void runFor(OOTimeDelta seconds);      // rounds up to whole ticks
  bool runUntil(std::function<bool()> done, OOTimeDelta limitSeconds);  // true if done happened
  OOTimeDelta elapsed() const;

  // Queries
  std::vector<std::weak_ptr<ShipEntity>> shipsWithRole(std::string_view role) const;
  std::vector<std::weak_ptr<Entity>> entitiesWithin(Vector centre, double radius) const;

  // Observing events
  struct Event { OOTimeDelta at; std::string name; uint32_t subject; uint32_t other; };
  const std::vector<Event>& events() const;  // e.g. "shipBeingAttacked", "shipDied", "shipDockedWithStation"
  uint64_t stateHash() const;            // positions, velocities, energy and status of every entity

  OOGame& game();
};
```

**Why weak references.** A test that kept a `std::shared_ptr` to a ship across `step()` would
keep a destroyed ship alive and change what the universe does. A `std::weak_ptr` lets the test
read a live ship (`lock()` inside one statement) and see a destroyed one as expired, once the
universe and the autorelease drain have let it go.

**How events are recorded.** The scenario registers an `OOGameEventObserver`, an optional
service in its context, called at the one place where entity script events are dispatched (today
the path through `ShipEntity::doScriptEvent`). The GUI program registers none, so the call is a
null check.

**Determinism.** For the same options and the same calls, `events()` and the series of
`stateHash()` values are identical (FR-007, SC-002).

## The first scenario (SC-001)

`tests/unit/scenario/test_scenario_combat.cpp` follows
`tests/component/features/s1_police_kills_pirate.feature`:

1. seed 20260910;
2. spawn one `police` ship and one `pirate` 10 km away, with the component scenario's pinned ship
   keys;
3. `runUntil` a police ship engages a pirate, within 112.5 s of game time;
4. check that a police ship survives.

The component scenario stays where it is, as the layer above.
