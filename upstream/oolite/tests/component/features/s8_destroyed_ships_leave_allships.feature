Feature: Entity lifetime

  Scenario: A destroyed ship leaves system.allShips
    Given a universe seeded with 20260910
    When I spawn 1 ship with role "pirate"
    And I spawn 8 ships with role "police" within 10 km
    Then 1 ships with role "pirate" remain
    And 8 ships with role "police" remain
    When the simulation runs for at most 900 ticks
    Then no ship with role "pirate" remains
    And 8 ships with role "police" remain
