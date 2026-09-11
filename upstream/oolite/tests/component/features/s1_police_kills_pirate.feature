Feature: Ship-to-ship combat

  Scenario: A police viper destroys a lone pirate
    Given a universe seeded with 20260910
    When I spawn 1 ship with role "police"
    And I spawn 1 ship with role "pirate" within 10 km
    And the simulation runs for at most 900 ticks
    Then no ship with role "pirate" remains
    And a ship with role "police" survives
