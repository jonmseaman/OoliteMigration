# SMOKE TEST (ADR-0020, docs/decisions/0020-component-scenarios-are-smoke-tests-for-now.md).
#
# This scenario does NOT prove "the FLEE branch, the most commonly broken AI transition"
# (docs/phases/0-component-tier.md, S6) and does NOT prove that range increases while a
# damaged ship flees. The step library (upstream/oolite/tests/component/steps/world_steps.py)
# has no step that samples a numeric range/distance more than once for comparison and no step
# that reads an AI behavioural-state transition, so neither half of the story's title can be
# asserted with the existing step catalogue (see oo-kbqw). Adding either is a new interface and
# out of scope here.
#
# What this DOES prove: the scenario's world setup (load, launch, spawn the named roles, set
# their AIs per ADR-0019) runs for the stated tick budget without the game logging an ERROR, and
# a ship with a role this scenario spawned is still alive afterwards. The real assertion -
# FLEE-state transition and increasing range - is deferred to oo-kbqw.
#
# oo-sjvz: the cast is pinned to LITERAL SHIP KEYS ("[viper]"/"[sidewinder]") rather than spawned
# by role. system.addShips(<role>, ...) draws the ship TYPE at random (Universe.m:4008
# -newShipWithRole: -> :3948 -> OOShipRegistry.m:276-279
# [[self probabilitySetForRole:role] randomObject]), so a role-spawned police ship is not always
# a GalCop Viper (max_energy 180) - it can be any other ship carrying the "police" role, with a
# different max_energy, changing whether it survives an encounter with a pirate that engages it
# before fleeing. The literal "[shipKey]" form is registered by OOShipRegistry.m:1229 at
# probability 1.0, i.e. no draw, which is the same fix tests/golden/combat.py and S1 use.

Feature: A damaged ship flees and range increases (smoke test)

  Scenario: Setup runs cleanly and a spawned ship survives the scenario duration
    Given a universe seeded with 20260918
    When I spawn 1 ship with role "police" using ship key "[viper]"
    And I spawn 1 ship with role "pirate" using ship key "[sidewinder]" within 10 km
    And the simulation runs for at most 900 ticks
    Then a ship with role "police" survives
    And no ERROR appears in the log
