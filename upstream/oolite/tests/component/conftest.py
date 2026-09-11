"""Fixtures for the component tier: one native game process per scenario, on its own port.

Every scenario gets a hard timeout with a forced kill, so a hung game fails the run instead of
wedging it (docs/phases/0-component-tier.md).
"""

import os
import socket
import threading

import pytest

from console import DebugConsole

# A scenario that has not finished by now is not going to. Generous because a single launch costs
# 5-10 s on a software renderer before any simulation starts.
SCENARIO_TIMEOUT_SECONDS = int(os.environ.get("OO_COMPONENT_TIMEOUT", "300"))


def pytest_addoption(parser):
    parser.addoption(
        "--oolite-app",
        action="store",
        default=os.environ.get("OO_APP_DIR", ""),
        help="Path to oolite.app (default: $OO_APP_DIR, else the test build in this checkout)",
    )


def _default_app_dir():
    here = os.path.dirname(os.path.abspath(__file__))
    oolite = os.path.abspath(os.path.join(here, "..", ".."))
    return os.path.join(oolite, "build", "meson_test", "oolite.app")


@pytest.fixture(scope="session")
def app_dir(pytestconfig):
    path = pytestconfig.getoption("--oolite-app") or _default_app_dir()
    if not os.path.isdir(path):
        pytest.fail(
            f"no Oolite build at {path}. Build it first (tools/build-windows.sh test) "
            "or pass --oolite-app."
        )
    return path


@pytest.fixture
def free_port():
    """A port the OS just confirmed is free.

    One game process per scenario means the hardcoded 8563 of tests/launch_snapshot.py cannot be
    reused: two scenarios would fight over it, and on Windows the loser binds successfully and
    then never sees a connection.
    """
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind(("127.0.0.1", 0))
    port = sock.getsockname()[1]
    sock.close()
    return port


class World:
    """Scenario state shared between steps: the console, the seed, and what was spawned."""

    def __init__(self, app_dir, port, output_dir):
        self.app_dir = app_dir
        self.port = port
        self.output_dir = output_dir
        self.console = None
        self.seed = None
        self.spawned = {}

    def start(self, seed):
        self.seed = seed
        self.console = DebugConsole(
            self.app_dir, self.port, seed=seed, output_dir=self.output_dir
        )
        self.console.start()
        return self.console

    def close(self):
        if self.console is not None:
            self.console.close()
            self.console = None


@pytest.fixture
def world(app_dir, free_port, tmp_path, request):
    """One game per scenario, killed unconditionally at the end.

    The timeout is enforced by a watchdog thread rather than a signal: SIGALRM does not exist on
    Windows, and this tier runs natively on Windows (ADR-0017).
    """
    w = World(app_dir, free_port, str(tmp_path))

    timed_out = threading.Event()

    def on_timeout():
        timed_out.set()
        w.close()

    watchdog = threading.Timer(SCENARIO_TIMEOUT_SECONDS, on_timeout)
    watchdog.daemon = True
    watchdog.start()
    try:
        yield w
    finally:
        watchdog.cancel()
        w.close()
        if timed_out.is_set():
            pytest.fail(
                f"scenario exceeded {SCENARIO_TIMEOUT_SECONDS}s and the game was killed"
            )
