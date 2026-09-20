# SMOKE SCENARIO (ADR-0020, descoping oo-on18): this does NOT prove "group and
# formation behaviour (OOShipGroup), which no other tier touches" - it only proves the
# setup for this story runs the stated ticks without crashing, and that a spawned escort
# is still alive afterwards. The real assertion (escorts closing distance on their mother,
# via Ship.escortGroup/Ship.escorts) is deferred to oo-bdl0, which needs a step library
# capability (per-ship identity / numeric sampling, cf. oo-kbqw) that does not exist yet.
#
# oo-sjvz: the cast is pinned to LITERAL SHIP KEYS ("[boa]" for the mother, "[sidewinder-escort]"
# for the escorts) rather than spawned by role. system.addShips(<role>, ...) draws the ship TYPE
# at random (Universe.m:4008 -newShipWithRole: -> :3948 -> OOShipRegistry.m:276-279
# [[self probabilitySetForRole:role] randomObject]), so a role-spawned run can hand this
# scenario a different, less survivable ship class run to run even at a pinned seed - the same
# non-determinism mechanism oo-qwk5 and tests/golden/combat.py measured for combat. The literal
# "[shipKey]" form is registered by OOShipRegistry.m:1229 at probability 1.0, i.e. no draw.
Feature: Escorts converge on their mother

  Scenario: A mother ship and her escorts fly without error
    Given a universe seeded with 20260910
    When I spawn 1 ship with role "trader" using ship key "[boa]"
    And I spawn 2 ships with role "escort" using ship key "[sidewinder-escort]" within 5 km
    And the simulation runs for at most 900 ticks
    Then a ship with role "escort" survives
    And no ERROR appears in the log
