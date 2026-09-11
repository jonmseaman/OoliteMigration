"""The step library. S2-S8 reuse these; adding a NEW step is a new interface, so it is a seam,
not fleet work - stop and file a bead (ADR-0018 section 5).

Every step drives the game through JS that already exists. Nothing here adds a native property:
assertions are built from countShipsWithRole, system.allShips and the entity/ship properties listed
in docs/phases/0-component-tier.md.
"""

import time

from pytest_bdd import given, when, then, parsers

# Ship AI thinks every 0.125 s (AI_THINK_INTERVAL, src/Core/AI.h:31). A "tick" in the scenario
# vocabulary is one of those decision intervals, which is what makes "within 900 ticks" mean
# roughly 120 AI decisions rather than 900 frames.
TICK_SECONDS = 0.125

# How often the run step asks the game for a count. Each round trip costs a console command, so
# polling far faster than the AI thinks buys nothing.
POLL_SECONDS = 0.5


def _js_string(value):
    """Quote a Python string for embedding in a JS source fragment."""
    return '"%s"' % str(value).replace("\\", "\\\\").replace('"', '\\"')


# --- Given ---------------------------------------------------------------------------------


@given(parsers.parse("a universe seeded with {seed:d}"))
def universe_seeded_with(world, seed):
    """Launch the game with OO_RANDOM_SEED pinned.

    This has to be the launch step, not a later one: GameController seeds RANROT once during
    -init, so the seed cannot be changed after the process is up.
    """
    world.start(seed)


# --- When ----------------------------------------------------------------------------------


@when(parsers.parse('I spawn {count:d} ship with role "{role}"'))
@when(parsers.parse('I spawn {count:d} ships with role "{role}"'))
def spawn_ships(world, count, role):
    # addShips(role, count [, position, radius]) returns the Array of ships it added
    # (OOJSSystem.m:943), so its length is the honest answer to "did I get what I asked for".
    added = world.console.evaluate_int(
        "system.addShips(%s, %d).length" % (_js_string(role), count)
    )
    if added != count:
        raise AssertionError(f"asked for {count} {role!r}, addShips returned {added}")
    world.spawned[role] = world.spawned.get(role, 0) + count


@when(parsers.parse('I spawn {count:d} ship with role "{role}" within {km:d} km'))
@when(parsers.parse('I spawn {count:d} ships with role "{role}" within {km:d} km'))
def spawn_ships_near(world, count, role, km):
    """Spawn near the existing action rather than anywhere in the system.

    The optional position/radius arguments of addShips take metres. The first ship already
    spawned is the only thing in an otherwise empty system worth measuring from, so use it when
    there is one and fall back to the origin when there is not.
    """
    js = (
        "(function(){"
        " var ships = system.allShips;"
        " var at = ships.length > 0 ? ships[0].position : [0, 0, 0];"
        " return system.addShips(%s, %d, at, %d).length;"
        "})()" % (_js_string(role), count, km * 1000)
    )
    added = world.console.evaluate_int(js)
    if added != count:
        raise AssertionError(
            f"asked for {count} {role!r} within {km} km, addShips returned {added}"
        )
    world.spawned[role] = world.spawned.get(role, 0) + count


@when(parsers.parse("the simulation runs for at most {ticks:d} ticks"))
def run_simulation(world, ticks):
    """Let the game run, stopping early once the scenario's quarry is gone.

    Polling for an early exit is what keeps the suite fast; the budget is a ceiling, not a wait.
    Reaching the ceiling is not a failure here - the Then steps decide that - but the step must
    never block past it.
    """
    budget = ticks * TICK_SECONDS
    deadline = time.time() + budget
    watched = [r for r in world.spawned if r != "police"]
    while time.time() < deadline:
        time.sleep(POLL_SECONDS)
        if not watched:
            continue
        if all(count_with_role(world, role) == 0 for role in watched):
            return


@when(parsers.parse("the simulation runs for {ticks:d} ticks"))
def run_simulation_fully(world, ticks):
    """Run the whole budget without an early exit, for scenarios asserting nothing happened."""
    time.sleep(ticks * TICK_SECONDS)


# --- Then ----------------------------------------------------------------------------------


def count_with_role(world, role):
    return world.console.evaluate_int(
        "system.countShipsWithRole(%s)" % _js_string(role)
    )


@then(parsers.parse('no ship with role "{role}" remains'))
def no_ship_with_role_remains(world, role):
    remaining = count_with_role(world, role)
    assert remaining == 0, f"{remaining} ship(s) with role {role!r} still alive"


@then(parsers.parse('a ship with role "{role}" survives'))
def ship_with_role_survives(world, role):
    remaining = count_with_role(world, role)
    assert remaining > 0, f"no ship with role {role!r} survived"


@then(parsers.parse('{count:d} ships with role "{role}" remain'))
def n_ships_with_role_remain(world, count, role):
    remaining = count_with_role(world, role)
    assert remaining == count, (
        f"expected {count} ship(s) with role {role!r}, found {remaining}"
    )


@then(parsers.parse("no ERROR appears in the log"))
def no_error_in_log(world):
    """The canary for NaN blowups and scan-class confusion (S7).

    Read after the game has quit, so the log is complete and closed.
    """
    import os

    world.close()
    log = os.path.join(world.output_dir, "Latest.log")
    if not os.path.isfile(log):
        raise AssertionError(f"no log written at {log}")
    with open(log, "r", encoding="utf-8", errors="replace") as handle:
        offenders = [line.rstrip() for line in handle if "ERROR" in line]
    assert not offenders, "ERROR lines in Latest.log:\n" + "\n".join(offenders[:20])
