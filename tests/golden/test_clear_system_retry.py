"""Offline proof for bug oo-pfern: the golden harness's clear-then-count survives an arrival.

launch_dock.clear_system (and run_dump.clear_system, which it copies) removes every non-player,
non-station ship and then counts them. A live universe can add a ship between those two console
commands (cargo pods from a removed ship's deferred dumpCargo calls, station launches - the sources
oo-hmnbb measured for the component tier), which failed scenario 001 about 1 run in 6 with
"1 non-station ship(s) remain after clearing". The clear now repeats until one clear-then-count
sees no non-station ship, and still fails when the system never empties.

No game is launched: a scripted console stands in for the debug console, so this takes well
under a second and no desktop lock.
"""

import os
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "dump"))

import launch_dock  # noqa: E402
import run_dump  # noqa: E402


class ScriptedConsole:
    """Answers the clear with a removal count and the non-station count from a script."""

    def __init__(self, module, counts):
        self.module = module
        self.counts = list(counts)
        self.clears = 0

    def evaluate_int(self, js):
        if js == self.module.CLEAR_NON_STATION_SHIPS_JS:
            self.clears += 1
            return 10 if self.clears == 1 else 1
        assert js == self.module.COUNT_NON_STATION_SHIPS_JS, "unexpected JS %r" % js
        return self.counts.pop(0)


@pytest.fixture(autouse=True)
def no_sleep(monkeypatch):
    monkeypatch.setattr(launch_dock.time, "sleep", lambda _seconds: None)
    monkeypatch.setattr(run_dump.time, "sleep", lambda _seconds: None)


def test_launch_dock_clears_an_arrival_on_the_next_pass():
    console = ScriptedConsole(launch_dock, [1, 0])
    assert launch_dock.clear_system(console) == 0
    assert console.clears == 2


def test_launch_dock_clears_once_when_nothing_arrives():
    console = ScriptedConsole(launch_dock, [0])
    assert launch_dock.clear_system(console) == 0
    assert console.clears == 1


def test_launch_dock_still_fails_when_the_system_never_empties():
    console = ScriptedConsole(launch_dock, [1] * launch_dock.CLEAR_ATTEMPTS)
    with pytest.raises(launch_dock.ScenarioError, match="1 non-station ship"):
        launch_dock.clear_system(console)
    assert console.clears == launch_dock.CLEAR_ATTEMPTS


def test_run_dump_clears_an_arrival_on_the_next_pass():
    console = ScriptedConsole(run_dump, [1, 0])
    run_dump.clear_system(console)
    assert console.clears == 2


def test_run_dump_still_fails_when_the_system_never_empties():
    console = ScriptedConsole(run_dump, [2] * run_dump.CLEAR_ATTEMPTS)
    with pytest.raises(SystemExit, match="2 non-station ship"):
        run_dump.clear_system(console)
    assert console.clears == run_dump.CLEAR_ATTEMPTS
