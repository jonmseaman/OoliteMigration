"""Binds the S8 feature file to the shared step library.

Each scenario gets its own module-level binding so pytest-bdd collects it as a test; the steps
themselves live in steps/world_steps.py and are shared with S1.

Why this scenario is written as pirate-versus-eight-police, and why the counts are the ones they
are - all measured against this build, seed 20260910, in an emptied system:

* ``system.countShipsWithRole`` and ``system.allShips`` read the SAME list. Both end in
  ``Universe``'s walk over ``sortedEntities`` (``countEntitiesMatchingPredicate``,
  ``Universe.m:6431``; ``allShips`` -> ``findShipsMatchingPredicate``, ``OOJSSystem.m:297``), so
  "the role count fell to zero" IS "the entity left ``system.allShips``". A leaked entity - the
  use-after-free ADR-0003 predicts - is one that stays in that list after it died, and it shows up
  here as a count that never drops.

* The kill has to actually happen, which S1 established a lone Viper cannot do: 180 max energy
  against a stock pirate's 706, so they circle for ever (ADR-0019). EIGHT vipers do kill it -
  measured twice, the pirate left ``system.allShips`` after 14 s and 24 s, against a ceiling of
  900 ticks (112 s).

* The scenario is deliberately not vacuous. The system populator repopulates an emptied system
  while the simulation runs, so "a ship with role X survives" can be satisfied by traffic that
  arrived on its own. That is why the pirate count is PINNED AT 1 immediately after the spawn and
  asserted at 0 after the run: the ship was demonstrably in the list and demonstrably left it.
  Measured over 160 s of this exact setup, the populator added an Orbital Shuttle and a metal
  fragment and never a pirate, so the zero is not at risk of being re-filled either.

* The police count is asserted EXACTLY, before and after, as the other half of entity lifetime:
  the ships that were not destroyed must still be in the list. Measured 8/8 at every sample over
  160 s, and police are not populator traffic in an emptied system (0 for 184 s with none
  spawned). The run step returns as soon as the pirate is gone, ~15-25 s in, well inside that.
"""

from pytest_bdd import scenarios

from steps.world_steps import *  # noqa: F401,F403  (step definitions register on import)

scenarios("features/s8_destroyed_ships_leave_allships.feature")
