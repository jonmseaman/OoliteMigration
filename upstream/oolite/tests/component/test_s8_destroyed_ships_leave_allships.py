"""Binds the S8 feature file to the shared step library.

Each scenario gets its own module-level binding so pytest-bdd collects it as a test; the steps
themselves live in steps/world_steps.py and are shared with S1.

*** THIS SCENARIO IS KNOWN FLAKY AND THE BEAD IS BLOCKED ON A STEP-CATALOGUE SEAM. ***
Do not read the counts in the feature file as validated. ``docs/stories/S8-measurements.md``
records what was actually measured with ``tools/oo-qwk5-probe.py`` on the shared build, seed
20260910, system Lave. The short version is that no cast expressible in the current step
catalogue destroys its quarry reliably:

* ``system.addShips("pirate", ...)`` gives each ship ``bounty = 20 + randf() * 50``
  (``Universe.m:4026``) - a DRAW - while ``policeAI`` only attacks a scanned ship above
  ``fineThreshold() = 50 - government * 6`` (``oolite-priorityai.js:845``), which is 32 in Lave.
  So in roughly a quarter of runs the pirate is not a criminal and the eight vipers never engage
  at all: measured directly at bounty 22, eight police stayed at ``hasHostileTarget`` false for
  the whole 110 s budget. That is a random draw, not a duration, so neither more police nor a
  wider tick budget can fix it - the previous attempt's "measured at 14 s and 24 s" was the
  favourable half of that draw.

* Reversing the cast does not help: ``pirateAI`` treats ``CLASS_POLICE`` through
  ``conditionScannerContainsHunters`` and LEAVES THE VICINITY rather than attacking, so 16
  pirates against one viper killed nothing in 148 s.

* The role count is also not exclusive to what the scenario spawned. The populator writes to the
  same population mid-run (observed ``pirate`` going 1 -> 2 at t=27.5 s with nothing spawned),
  so a zero can be re-filled by traffic the scenario never created.

What S8 needs is either a step that sets a spawned ship's bounty (``ship.bounty`` is already
writable from JS, ``OOJSShip.m:1378``) so the police's attack condition is a fact of the scenario
rather than a draw, or a per-ship handle (oo-kbqw / oo-bdl0) so the assertion names the ship that
was spawned rather than a role the populator also writes to. Both are new entries in the step
catalogue, which is a new interface and therefore sizing check 5 (ADR-0018 section 5) - stop and
file, do not add one inside a conversion story.

The property the scenario is trying to state remains correct and is worth keeping written down:
``system.countShipsWithRole`` and ``system.allShips`` read the SAME list (``Universe.m:6431``
``countEntitiesMatchingPredicate``; ``OOJSSystem.m:297`` ``findShipsMatchingPredicate``), so
"the role count fell to zero" IS "the entity left ``system.allShips``", and the leaked entity
ADR-0003 predicts shows up here as a count that never drops.
"""

from pytest_bdd import scenarios

from steps.world_steps import *  # noqa: F401,F403  (step definitions register on import)

scenarios("features/s8_destroyed_ships_leave_allships.feature")
