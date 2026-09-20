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

# A save has to be loaded to get a running simulation; this one ships with the game.
SCENARIO_SAVE = "Resources/Scenarios/oolite-standard.oolite-save"

# Launching out of the station takes a few seconds of real time on a software renderer.
LAUNCH_TIMEOUT_SECONDS = 60

# system.addShips gives every ship nullAI.plist - an inert ship that never thinks, never acquires
# a target and never fires. Measured: two ships, 900 ticks, AIState GLOBAL throughout and full
# energy on both. A scenario about combat therefore has to install the role's real AI, which is
# what the system populator would have done. Names from ai_type in Resources/Config/shipdata.plist.
ROLE_AI = {
    "police": "oolite-policeAI.js",
    "pirate": "oolite-pirateAI.js",
    "trader": "oolite-traderAI.js",
    "shuttle": "oolite-shuttleAI.js",
}

# Where an unpositioned spawn goes. Left to itself addShips scatters ships anywhere in the system
# - measured 415 km apart - so nothing ever meets anything. Scenarios spawn around one locus.
SPAWN_RADIUS_M = 5000


def _js_string(value):
    """Quote a Python string for embedding in a JS source fragment."""
    return '"%s"' % str(value).replace("\\", "\\\\").replace('"', '\\"')


# --- Given ---------------------------------------------------------------------------------


@given(parsers.parse("a universe seeded with {seed:d}"))
def universe_seeded_with(world, seed):
    """Launch the game with OO_RANDOM_SEED pinned, into an empty but running system.

    Two things have to be true at once, and neither is free.

    The simulation must actually be running. Left at the main menu the game shows a demo scene:
    there is a docked player and a station, but no AI runs, so spawned ships sit in AIState
    GLOBAL with no target for ever. Measured: 90 s, zero movement, zero targets. A save has to be
    loaded to get a live universe, and there is no JS route out of the intro screen - that is
    keyboard work and belongs to the GUI tier.

    The system must also be empty, and a loaded save is anything but: the standard scenario opens
    with roughly 80 entities including 32 pirates and 5 police. "No ship with role pirate
    remains" is unreachable in that, and would be measuring the ambient population rather than
    the scenario. So the system is cleared down to the player before anything is spawned.

    RANROT is seeded once in GameController -init, which is why the seed belongs to this step and
    cannot be changed later.
    """
    world.start(seed, load_save=SCENARIO_SAVE)

    # A loaded save starts docked, and while docked the game is sitting on station screens rather
    # than flying the system - NPC AI does not tick, which is why every ship reports AIState
    # GLOBAL with no target no matter how long you wait. Launching puts the universe in flight.
    world.console.perform("player.ship.launch();")
    deadline = time.time() + LAUNCH_TIMEOUT_SECONDS
    while time.time() < deadline:
        time.sleep(1)
        if world.console.evaluate("player.ship.docked").strip().lower() == "false":
            break
    else:
        raise AssertionError(
            f"player never launched within {LAUNCH_TIMEOUT_SECONDS}s; the system would not be "
            "simulated and no scenario below it can mean anything"
        )
    # Let the launch settle so the player is clear of the station before the system is emptied.
    time.sleep(2)

    removed = world.console.evaluate_int(
        "(function(){"
        " var ships = system.allShips, n = 0;"
        " for (var i = 0; i < ships.length; i++) {"
        "   if (!ships[i].isPlayer) { ships[i].remove(); n++; }"
        " }"
        " return n; })()"
    )
    remaining = world.console.evaluate_int("system.allShips.length")
    if remaining > 1:
        raise AssertionError(
            f"cleared {removed} ships but {remaining} remain; the scenario would be measuring "
            "the ambient population rather than what it spawned"
        )


# --- When ----------------------------------------------------------------------------------


# NOTE ON PARSER CHOICE: pytest-bdd's default parsers.parse() (the `parse` library) lets a bare
# "{role}" match ANY characters, including quotes - so 'I spawn 1 ship with role "pirate" using
# ship key "[x]" within 10 km' can ALSO fully parse against the plainer '... role "{role}"
# within {km:d} km' pattern, with role swallowing 'pirate" using ship key "[x]' right up to the
# literal '" within 10 km' suffix that both texts happen to share. That produced a real failure
# here (role names would carry garbage) regardless of decorator registration order. The fix is
# parsers.re with an explicit [^"]+ character class for role/key, which cannot cross a quote and
# therefore cannot mis-match a step text it was not written for.
_ROLE = r'(?P<role>[^"]+)'
_KEY = r'(?P<key>\[[^\]]+\])'


@when(parsers.re(r'I spawn (?P<count>\d+) ships? with role "%s" using ship key "%s" within '
                  r'(?P<km>\d+) km' % (_ROLE, _KEY)))
def spawn_ships_by_key_near(world, count, role, key, km):
    _spawn(world, int(count), role, "__ooLocus", int(km) * 1000, ship_key=key)


@when(parsers.re(r'I spawn (?P<count>\d+) ships? with role "%s" using ship key "%s"'
                  % (_ROLE, _KEY)))
def spawn_ships_by_key(world, count, role, key):
    """Deterministic sibling of ``I spawn ... with role``: pin the cast to a literal ship key.

    ``system.addShips(role, ...)`` draws the ship TYPE at random (Universe.m:4008
    -newShipWithRole: -> :3948 randomShipKeyForRoleRespectingConditions: ->
    OOShipRegistry.m:276-279 ``[[self probabilitySetForRole:role] randomObject]``), so the same
    seed can still hand a scenario a different ship class run to run depending on how many RANROT
    draws happened before the spawn - and for a combat-engagement scenario the ship class can
    decide whether the AI precondition (e.g. policeAI's bounty-gated fineThreshold check) is even
    satisfiable (see oo-qwk5: ~24% of role-spawned pirates were not legally attackable at all).
    ``[shipKey]`` is the literal-key form every ship is auto-registered under at probability 1.0
    (OOShipRegistry.m:1229), so this resolves through the same addShips call with NO draw to
    make - see fleet exemplar tests/golden/combat.py finding (1).
    """
    _spawn(world, int(count), role, "player.ship.position", SPAWN_RADIUS_M, ship_key=key)


@when(parsers.re(r'I spawn (?P<count>\d+) ships? with role "%s" within (?P<km>\d+) km' % _ROLE))
def spawn_ships_near(world, count, role, km):
    """Spawn near the existing action rather than anywhere in the system.

    The optional position/radius arguments of addShips take metres. The first ship already
    spawned is the only thing in an otherwise empty system worth measuring from, so use it when
    there is one and fall back to the origin when there is not.
    """
    _spawn(world, int(count), role, "__ooLocus", int(km) * 1000)


@when(parsers.re(r'I spawn (?P<count>\d+) ships? with role "{role}"'.replace("{role}", _ROLE)))
def spawn_ships(world, count, role):
    _spawn(world, int(count), role, "player.ship.position", SPAWN_RADIUS_M)


def _spawn(world, count, role, at_js, radius_m, ship_key=None):
    """Spawn ships around a locus and give them the AI their role would normally fly with.

    addShips(role, count [, position, radius]) returns the Array of ships it added
    (OOJSSystem.m:943), so its length is the honest answer to "did I get what I asked for".

    When ``ship_key`` is given, that literal ``[shipKey]`` selector is what is actually passed to
    addShips (removing the random ship-type draw), and every spawned ship then has its
    ``primaryRole`` forced back to ``role`` (OOJSShip.m:439, OOJS_PROP_READWRITE_CB) - because
    Universe.m:4014 ``[ship setPrimaryRole:role]`` would otherwise set primaryRole to the literal
    key string itself, breaking every Then step and AI precondition that compares primaryRole
    against the scenario's role name. Doing this unconditionally (also on the plain role-spawn
    path, where it is a harmless no-op re-affirming what addShips already set) keeps _spawn one
    code path instead of two.

    The first spawn of a scenario also fixes __ooLocus, the point later "within N km" spawns
    measure from. debugConsole is a writable JS global (OODebugMonitor.m:761), which is the
    documented place to keep scratch state between commands.
    """
    ai = ROLE_AI.get(role)
    selector = ship_key if ship_key else role
    js = (
        "(function(){"
        " var at = %s;"
        " var added = system.addShips(%s, %d, at, %d);"
        " if (!added) return 0;"
        " if (typeof debugConsole.__ooLocus === 'undefined' && added.length > 0)"
        "   debugConsole.__ooLocus = added[0].position;"
        " for (var i = 0; i < added.length; i++) {"
        "   added[i].primaryRole = %s;"
        "   %s"
        " }"
        " return added.length; })()"
        % (
            "debugConsole.__ooLocus" if at_js == "__ooLocus" else at_js,
            _js_string(selector),
            count,
            radius_m,
            _js_string(role),
            ("added[i].setAI(%s);" % _js_string(ai)) if ai else "",
        )
    )
    added = world.console.evaluate_int(js)
    if added != count:
        raise AssertionError(
            f"asked for {count} {role!r} (ship key {ship_key!r}), addShips returned {added}"
        )
    world.spawned[role] = world.spawned.get(role, 0) + count


@when(parsers.re(r'the ship with role "%s" has bounty (?P<bounty>\d+)' % _ROLE))
def set_bounty_for_role(world, role, bounty):
    """Pin bounty explicitly so a combat precondition is a fact, not a spawn-time draw.

    A literal-key spawn passes the KEY, not the role, as addShips' first argument, so it never
    reaches Universe.m:4026's ``if ([role isEqualToString:@"pirate"]) [ship setBounty:20 +
    randf() * 50 ...]`` - the role-spawn path's own coin flip that oo-qwk5 measured leaves ~24%
    of pirates below policeAI's fineThreshold() (oolite-priorityai.js:845,
    ``50 - government*6``) and therefore not legally attackable at all. ``ship.bounty`` is
    OOJS_PROP_READWRITE_CB (OOJSShip.m:349, setter case :1374), already used read-write
    elsewhere in this tier, so writing it converts the engagement precondition from a draw into
    a fact of the scenario.
    """
    bounty = int(bounty)
    n = world.console.evaluate_int(
        "(function(){ var s = system.allShips, n = 0;"
        " for (var i = 0; i < s.length; i++) {"
        "   if (s[i].primaryRole == %s) { s[i].bounty = %d; n++; } }"
        " return n; })()" % (_js_string(role), bounty)
    )
    if n < 1:
        raise AssertionError(f"no ship with role {role!r} found to set bounty on")


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


@then(parsers.parse('within {ticks:d} ticks a ship with role "{hunter}" '
                   'engages a ship with role "{quarry}"'))
def engages_within(world, ticks, hunter, quarry):
    """Poll until a hunter has the quarry as a hostile target, or the budget runs out.

    Engagement rather than a kill, and measured rather than assumed - see ADR-0019. A GalCop
    Viper has 180 max energy against a stock pirate's 706, so it cannot win: observed over 320 s
    the police dropped to 130/180 and regenerated while the pirate never fell below 682/706. They
    simply circle. Engagement, by contrast, is quick and unambiguous: target acquired and
    hasHostileTarget set within ~17 s (about 136 ticks) of the spawn, against this budget of 900.

    Returning as soon as it is true is what keeps the scenario ~20 s instead of the full 112 s.
    """
    js = (
        "(function(){ var r = 0;"
        " system.allShips.forEach(function(s){"
        "   if (s.primaryRole == %s && s.hasHostileTarget"
        "       && s.target && s.target.primaryRole == %s) r = 1;"
        " });"
        " return r; })()" % (_js_string(hunter), _js_string(quarry))
    )
    deadline = time.time() + ticks * TICK_SECONDS
    while time.time() < deadline:
        # A generous per-command timeout: the game is flying a dogfight on a software renderer
        # and two cores, so a console round trip is not always prompt.
        if world.console.evaluate_int(js, timeout=45) == 1:
            return
        time.sleep(POLL_SECONDS)
    raise AssertionError(
        f"no ship with role {hunter!r} took a ship with role {quarry!r} as a hostile target "
        f"within {ticks} ticks"
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
