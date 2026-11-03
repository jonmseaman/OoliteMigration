# Contract: headless scenario test support

This is test-only support code in `oolite-dev/tests/unit/scenario/`. It holds `oo_scenario.hpp`
plus its `.cpp`, built on `OOGame`'s public interface. The production interface stays small: what
a test needs that the game does not belongs here, not in `src/`.

```cpp
struct OOScenarioOptions {
  uint64_t seed = 20260910;
  std::string system = "Lave";           // the system to start in (galaxy 0)
  OOTimeDelta tickSeconds = 1.0 / 60;    // the fixed step (research R6)
};

class OOScenario {
 public:
  explicit OOScenario(OOScenarioOptions options = {});
  // Builds an OOGame with headless context options, a universe from OOUniverseOptions{NONE,
  // populate=false, detail=minimum}, and the player in flight at the origin. Holds an
  // OOGameContextScope for its lifetime.

  // Spawning
  ShipEntity* spawn(std::string_view role, Vector position);
  ShipEntity* spawnShip(std::string_view shipKey, Vector position);  // a pinned key, as in tests/component
  void spawnAsteroidField(Vector centre, unsigned count, double radius);
  ShipEntity* player();

  // Time
  void step(unsigned ticks = 1);
  void runFor(OOTimeDelta seconds);      // rounds up to whole ticks
  bool runUntil(std::function<bool()> done, OOTimeDelta limitSeconds);  // true if done happened
  OOTimeDelta elapsed() const;

  // Queries
  std::vector<ShipEntity*> shipsWithRole(std::string_view role) const;
  std::vector<Entity*> entitiesWithin(Vector centre, double radius) const;

  // Observing events
  struct Event { OOTimeDelta at; std::string name; uint32_t subject; uint32_t other; };
  const std::vector<Event>& events() const;  // e.g. "shipBeingAttacked", "shipDied", "shipDockedWithStation"
  uint64_t stateHash() const;            // hashes positions, velocities, energy and status of every entity

  OOGame& game();
};
```

**How events are recorded.** The scenario registers an `OOGameEventObserver`, an optional
service in the context. It is called at the one place where entity script events are
dispatched, which is today the path through `ShipEntity::doScriptEvent`. The GUI program
registers none, so the call is a null check.

**Determinism.** For the same options and the same sequence of calls, `events()` and the series
of `stateHash()` values are identical (FR-007, SC-002).

## The first scenario (SC-001)

`tests/unit/scenario/test_scenario_combat.cpp` follows
`tests/component/features/s1_police_kills_pirate.feature`:

1. seed 20260910;
2. spawn one `police` ship and one `pirate` 10 km away, using the same pinned ship keys as the
   component scenario;
3. `runUntil` a police ship engages a pirate, within 112.5 s of game time;
4. check that a police ship survives.

The component scenario stays where it is, as the layer above.
