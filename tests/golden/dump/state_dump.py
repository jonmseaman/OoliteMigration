"""Shared glue for the oo-gla canonical dump: build the JS, run it, and spawn a deterministic
scenario to run it against.

Kept separate from dump_state.js on purpose: the JS is the thing under test (it runs inside the
game), this file is Python driving the console the same way tests/component/console.py and
tests/golden/golden_run.py already do (ADR-0018: console.py is the shared transport).
"""

import json
import os
import time

HERE = os.path.dirname(os.path.abspath(__file__))
DUMP_JS_PATH = os.path.join(HERE, "dump_state.js")


def start_with_retry(make_console, attempts=8, ready_timeout=180):
    """Build and start a fresh DebugConsole, retrying a handful of times.

    `make_console` is a zero-arg factory (not a console instance): native process launch on this
    VM occasionally fails with WinError-class DLL-load races before the game ever reaches main()
    (observed: STATUS_DLL_NOT_FOUND, exit code 3221225781) - nothing to do with the dump itself,
    unrelated to determinism (also seen and documented independently on bead oo-16s's Mesa
    staging), but it can leave the failed DebugConsole's listening socket bound. A fresh instance
    per attempt avoids retrying start() on an already-bound port. Backoff grows because the
    underlying race has been observed to persist for tens of seconds on a loaded VM.
    """
    from console import ConsoleError

    last = None
    for attempt in range(attempts):
        console = make_console()
        try:
            console.start(ready_timeout=ready_timeout)
            return console
        except ConsoleError as exc:
            last = exc
            try:
                console.close()
            except Exception:
                pass
            time.sleep(min(30, 3 * (attempt + 1)))
    raise last


def dump_js_source():
    with open(DUMP_JS_PATH, "r", encoding="utf-8") as handle:
        return handle.read()


def dump_state(console, timeout=30):
    """Run the dump inside the game and return the raw JSON text it printed.

    console.evaluate() already wraps the expression in String(...) and marker-delimits the
    reply (tests/component/console.py:210), so the dump script's JSON.stringify(...) result comes
    back as a Python str unmodified - JSON.stringify never emits the console's own marker
    characters, so no collision is possible.
    """
    return console.evaluate(dump_js_source(), timeout=timeout)


def dump_state_parsed(console, timeout=30):
    return json.loads(dump_state(console, timeout=timeout))


# --- deterministic scenario setup -------------------------------------------------------------
#
# Ship identity for sorting: shipUniqueName, zero-padded per role so a lexicographic sort is a
# spawn-order sort (tests/component/steps/world_steps.py already gives ships their role's real AI
# the same way; this only ADDS a deterministic name on top, addShips itself does not name ships).

_SPAWN_JS = (
    "(function(){"
    " var at = player.ship.position;"
    " var added = system.addShips(%(role)r, %(count)d, at, %(radius)d);"
    " if (!added) return 0;"
    " for (var i = 0; i < added.length; i++) {"
    "   added[i].shipUniqueName = %(role)r + '-' + ('000' + i).slice(-3);"
    "   %(ai)s"
    " }"
    " return added.length; })()"
)


def spawn_deterministic(console, role, count, radius_m=2000, ai=None):
    """Spawn `count` ships of `role`, named `<role>-000`, `<role>-001`, ... for a stable sort key.

    Mirrors tests/component/steps/world_steps.py::_spawn (ADR-0018's step catalogue) but adds the
    explicit name, which that step does not need because component-tier assertions never sort
    ships - this dump does, and iteration order over an unordered NSDictionary/JS-array-from-
    addShips is exactly the class of bug docs/fleet/LEARNINGS.md and bead oo-djn are about.
    """
    ai_js = ("added[i].setAI(%r);" % ai) if ai else ""
    js = _SPAWN_JS % {"role": role, "count": count, "radius": radius_m, "ai": ai_js}
    added = console.evaluate_int(js)
    if added != count:
        raise AssertionError("asked for %d %r, addShips returned %d" % (count, role, added))
    return added


def run_ticks(console, ticks, tick_seconds=0.125):
    """Advance the simulation for N AI-think ticks of GAME time (never the harness clock).

    NOT used by run_dump.py's default flow: run_once() pauses instead (see its docstring for why
    that is sufficient for decision 11's determinism requirement without fixed-delta-t stepping).
    Kept for a scenario that genuinely needs the AI to move, where the caller accepts that two
    dumps then differ unless the caller pins delta_t itself - out of scope for this bead.

    Uses clock.absoluteSeconds the same way tests/golden/golden_run.py::_wait_until_rendering
    does, rather than time.sleep, so the dump is reproducible independent of how slow the host
    happens to render any one run.
    """
    budget = ticks * tick_seconds
    start = float(console.evaluate("clock.absoluteSeconds"))
    deadline_wall = time.time() + max(60.0, budget * 4)
    while time.time() < deadline_wall:
        elapsed = float(console.evaluate("clock.absoluteSeconds")) - start
        if elapsed >= budget:
            return elapsed
        time.sleep(0.1)
    raise AssertionError("game time did not advance %ss within the wall budget" % budget)
