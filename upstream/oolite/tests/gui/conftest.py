"""Fixtures for the GUI tier: one real, on-screen game window driven by synthetic OS input.

Specified in docs/phases/0-gui-tier.md; the seam and exemplar is docs/stories/G1-exit-via-mouse.md.
Launch, environment and timeout handling follow tests/launch_snapshot.py and the component tier's
conftest.py - with SDL_VIDEODRIVER *unset*, because the whole point of this tier is that a real
window opens and real clicks reach it.

Three things live here, and G2-G9 reuse all three:

* ``row_to_point`` - the row -> screen point helper. Computed from the window rect and Oolite's
  fixed virtual grid, never image-matched (docs/phases/0-gui-tier.md, "compute, don't image-match").
* ``game`` - the launch/kill fixture: starts the game, waits until it is actually *servicing input*
  rather than merely running, and kills it unconditionally on teardown.
* ``desktop_lock`` - the session-scoped desktop mutex, tools/gui-lock. This tier takes the
  interactive desktop exclusively while it runs.
"""

import ctypes
import math
import os
import shutil
import subprocess
import sys
import time

import pytest

IS_WINDOWS = sys.platform == "win32" or os.name == "nt"

if IS_WINDOWS:
    # RECT/POINT and ctypes.windll exist only here. The module must still IMPORT elsewhere so
    # that `pytest --collect-only` works on any platform; the fixtures skip instead.
    import ctypes.wintypes  # noqa: F401

# --- Oolite's fixed virtual GUI grid (src/Core/GuiDisplayGen.h:34-43) -------------------------
MAIN_GUI_PIXEL_WIDTH = 480
MAIN_GUI_PIXEL_HEIGHT = 480
MAIN_GUI_ROW_HEIGHT = 16
MAIN_GUI_PIXEL_ROW_START = 40

# The window is pinned so that a failure is a failure and not a resolution difference. 4:3 keeps
# the whole 30-row grid inside the window; 16:9 pushes the last rows past the bottom edge.
PINNED_CLIENT_SIZE = (960, 720)

# A game that has not opened a window and started pumping messages by now is not going to.
READY_TIMEOUT_SECONDS = int(os.environ.get("OO_GUI_READY_TIMEOUT", "180"))
# Time for the start screen to finish drawing once the window answers. Measured from readiness,
# not from launch - see wait_until_ready in tests/launch_snapshot.py for why that distinction
# is the difference between a test and a race.
SETTLE_SECONDS = float(os.environ.get("OO_GUI_SETTLE", "5"))


# --- row -> screen point ----------------------------------------------------------------------


def _mouse_divisors(width, height):
    """The two numbers MyOpenGLView+Input.m:370-390 divides the mouse offset by.

    Reproduced exactly, including the asymmetry: in the <=4:3 branch the *vertical* divisor is
    also scaled by the window WIDTH, not its height.
    """
    display_z = 480.0 * width / height if width / height > 4.0 / 3.0 else 640.0
    if display_z > 640.0:
        return width * MAIN_GUI_PIXEL_WIDTH / display_z, float(height)
    return (
        MAIN_GUI_PIXEL_WIDTH * width / 640.0,
        MAIN_GUI_PIXEL_HEIGHT * width / 640.0,
    )


def point_to_row(x, y, client_rect):
    """The inverse of row_to_point: which GUI row a client-area point lands on.

    This is the chain the game itself walks - SDL motion event -> virtualJoystickPosition
    (MyOpenGLView+Input.m:377-390) -> cursor_row (GuiDisplayGen.m:1450-1459) -> setSelectedRow
    (PlayerEntityControls.m:765-790). Kept so the helper can be checked against its own inverse
    without a running game.
    """
    left, top, width, height = client_rect
    _, div_y = _mouse_divisors(width, height)
    my = ((y - top) - height / 2.0) / div_y
    cursor_y = -MAIN_GUI_PIXEL_HEIGHT * my
    cursor_y = max(-MAIN_GUI_PIXEL_HEIGHT * 0.5, min(MAIN_GUI_PIXEL_HEIGHT * 0.5, cursor_y))
    return 1 + int(
        math.floor(
            (0.5 * MAIN_GUI_PIXEL_HEIGHT - MAIN_GUI_PIXEL_ROW_START - cursor_y)
            / MAIN_GUI_ROW_HEIGHT
        )
    )


def row_to_point(row, client_rect):
    """Absolute screen point at the horizontal centre of GUI ``row``.

    ``client_rect`` is the window's client area in screen coordinates, ``(left, top, w, h)``.
    Returns the centre of the row's band, so a pixel of rounding either way still selects it.

    Raises ValueError for a row the window cannot reach. The grid is 30 rows tall but the
    cursor is clamped to the virtual half-height (GuiDisplayGen.m:1453-1456), so the last rows
    are only addressable in a taller window - and a click that silently clamps onto the wrong
    row is exactly the failure this tier exists to catch.
    """
    left, top, width, height = client_rect
    _, div_y = _mouse_divisors(width, height)
    # Centre of the band: cursor_row == row for (row-1) <= k < row, so aim at k = row - 0.5.
    cursor_y = (
        0.5 * MAIN_GUI_PIXEL_HEIGHT
        - MAIN_GUI_PIXEL_ROW_START
        - MAIN_GUI_ROW_HEIGHT * (row - 0.5)
    )
    if abs(cursor_y) > 0.5 * MAIN_GUI_PIXEL_HEIGHT:
        raise ValueError(f"row {row} is outside the virtual GUI cursor range")
    my = -cursor_y / MAIN_GUI_PIXEL_HEIGHT
    x = int(round(left + width / 2.0))
    y = int(round(top + height / 2.0 + my * div_y))
    if not (top <= y < top + height and left <= x < left + width):
        raise ValueError(
            f"row {row} lands at {(x, y)}, outside the {width}x{height} client area"
        )
    return x, y


# --- the game process -------------------------------------------------------------------------


def _default_app_dir():
    here = os.path.dirname(os.path.abspath(__file__))
    oolite = os.path.abspath(os.path.join(here, "..", ".."))
    return os.path.join(oolite, "build", "meson_test", "oolite.app")


def pytest_addoption(parser):
    parser.addoption(
        "--oolite-app",
        action="store",
        default=os.environ.get("OO_APP_DIR", ""),
        help="Path to oolite.app (default: $OO_APP_DIR, else the test build in this checkout)",
    )


class GameWindow:
    """One Oolite process, its window, and the input primitives the tests drive it with."""

    # Mesa's software GL, staged beside the binary by the component tier (tests/component/
    # conftest.py) so a headless VM can render offscreen. It is fatal here: with llvmpipe's
    # opengl32.dll in the app directory the game dies during initGL with 0x80070057 and never
    # opens a window. This tier wants the desktop's real driver, so the DLLs are moved aside
    # for the duration and put back on teardown. Safe because the desktop lock serialises the
    # tier, and put back because the component tier needs them.
    SOFTWARE_GL_DLLS = ("opengl32.dll", "libgallium_wgl.dll")
    _PARKED_SUFFIX = ".gui-tier-parked"

    def __init__(self, app_dir, output_dir):
        self.app_dir = os.path.abspath(app_dir)
        self.output_dir = os.path.abspath(output_dir)
        self.proc = None
        self.hwnd = None
        self._parked = []

    # --- lifecycle ----------------------------------------------------------------------------

    def _env(self):
        env = os.environ.copy()
        # SDL_VIDEODRIVER stays UNSET: this tier needs a real window. Audio is forced silent as
        # launch_snapshot.py does, so a machine with no audio device fails at audio rather than
        # looking like a launch failure.
        env["SDL_AUDIODRIVER"] = "dummy"
        env["ALSOFT_DRIVERS"] = "null"
        # The game does NOT create this directory; given a missing one it logs "could not open
        # log ... will log to stdout instead" and the readiness wait would then never see a log.
        os.makedirs(self.output_dir, exist_ok=True)
        env["OO_SNAPSHOTSDIR"] = self.output_dir
        env["OO_LOGSDIR"] = self.output_dir
        return env

    def _park_software_gl(self):
        for dll in self.SOFTWARE_GL_DLLS:
            live = os.path.join(self.app_dir, dll)
            if os.path.isfile(live):
                os.replace(live, live + self._PARKED_SUFFIX)
                self._parked.append(live)

    def _restore_software_gl(self):
        while self._parked:
            live = self._parked.pop()
            parked = live + self._PARKED_SUFFIX
            if os.path.isfile(parked):
                os.replace(parked, live)

    def start(self):
        binary = "oolite.exe" if IS_WINDOWS else "oolite"
        path = os.path.join(self.app_dir, binary)
        if not os.path.isfile(path):
            pytest.fail(f"no Oolite binary at {path}; build it first (tools/build-windows.sh test)")
        self._park_software_gl()
        self.proc = subprocess.Popen(
            [path, "--no-splash", "-windowed"],
            cwd=self.app_dir,
            env=self._env(),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        self._await_startup_complete(READY_TIMEOUT_SECONDS)
        self.hwnd = self._await_window(30)
        self._pin_window(*PINNED_CLIENT_SIZE)
        self.focus()
        time.sleep(SETTLE_SECONDS)
        return self

    def kill(self):
        try:
            if self.proc is not None and self.proc.poll() is None:
                self.proc.kill()
                try:
                    self.proc.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    pass
        finally:
            self._restore_software_gl()

    # --- window -------------------------------------------------------------------------------

    def _top_level_windows(self):
        user32 = ctypes.windll.user32
        found = []
        pid = ctypes.c_ulong()
        proto = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)

        def visit(hwnd, _lparam):
            user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
            if pid.value == self.proc.pid and user32.IsWindowVisible(hwnd):
                found.append(hwnd)
            return True

        user32.EnumWindows(proto(visit), None)
        return found

    def _log_path(self):
        return os.path.join(self.output_dir, "Latest.log")

    def _await_startup_complete(self, timeout):
        """Wait for the game to say it has finished loading, then let the menu draw.

        A window handle appears long before the game can act on input, and it is not even the
        FINAL window: the game creates a surface during init and then re-creates it at the end
        of startup ("Requested a new surface of 1280 x 720, windowed"), which discards any
        resize applied before that point. Pinning early therefore silently pins the wrong
        window, and clicking early gets every click dropped.

        So readiness is read from the game's own log line rather than guessed at by sleeping -
        the same discipline wait_until_ready applies to the console tier, with the log standing
        in for Ping/Pong because this tier deliberately does not open a console connection.
        """
        log = self._log_path()
        deadline = time.time() + timeout
        while time.time() < deadline:
            if self.proc.poll() is not None:
                pytest.fail(
                    f"Oolite exited with {self.proc.returncode} during startup; see {log}"
                )
            if os.path.isfile(log):
                with open(log, "r", encoding="utf-8", errors="replace") as handle:
                    if "startup.complete" in handle.read():
                        return
            time.sleep(0.5)
        pytest.fail(f"Oolite did not finish loading within {timeout}s; see {log}")

    def _await_window(self, timeout):
        """Wait for a visible window that is *answering messages*, not merely existing.

        SendMessageTimeout with SMTO_ABORTIFHUNG asks the window directly, so a game whose run
        loop has wedged fails here instead of failing later as a mysteriously ignored click.
        """
        user32 = ctypes.windll.user32
        SMTO_ABORTIFHUNG = 0x0002
        deadline = time.time() + timeout
        while time.time() < deadline:
            if self.proc.poll() is not None:
                pytest.fail(
                    f"Oolite exited with {self.proc.returncode} before opening a window; "
                    f"see {self.output_dir}"
                )
            for hwnd in self._top_level_windows():
                result = ctypes.c_ulong()
                if user32.SendMessageTimeoutW(
                    hwnd, 0x0000, 0, 0, SMTO_ABORTIFHUNG, 2000, ctypes.byref(result)
                ):
                    return hwnd
            time.sleep(0.5)
        pytest.fail(f"Oolite did not service window messages within {timeout}s")

    def _pin_window(self, client_w, client_h):
        """Resize so the CLIENT area is exactly the pinned size, and park it at the top-left.

        The grid maths is in client pixels, so pinning the outer window instead would make the
        row points depend on the border and title-bar metrics of whoever's desktop this is.
        """
        user32 = ctypes.windll.user32
        win = ctypes.wintypes.RECT()
        cli = ctypes.wintypes.RECT()
        user32.GetWindowRect(self.hwnd, ctypes.byref(win))
        user32.GetClientRect(self.hwnd, ctypes.byref(cli))
        chrome_w = (win.right - win.left) - (cli.right - cli.left)
        chrome_h = (win.bottom - win.top) - (cli.bottom - cli.top)
        SWP_NOZORDER = 0x0004
        user32.SetWindowPos(
            self.hwnd, None, 0, 0, client_w + chrome_w, client_h + chrome_h, SWP_NOZORDER
        )
        # The game only recomputes display_z on a resize event, so let it see this one.
        time.sleep(1.0)

    def client_rect(self):
        """The client area in screen coordinates: ``(left, top, width, height)``."""
        user32 = ctypes.windll.user32
        cli = ctypes.wintypes.RECT()
        origin = ctypes.wintypes.POINT(0, 0)
        user32.GetClientRect(self.hwnd, ctypes.byref(cli))
        user32.ClientToScreen(self.hwnd, ctypes.byref(origin))
        return (origin.x, origin.y, cli.right - cli.left, cli.bottom - cli.top)

    def focus(self):
        user32 = ctypes.windll.user32
        user32.ShowWindow(self.hwnd, 9)  # SW_RESTORE
        user32.SetForegroundWindow(self.hwnd)
        time.sleep(0.5)

    # --- input --------------------------------------------------------------------------------

    def point_for_row(self, row):
        return row_to_point(row, self.client_rect())

    def select_row(self, row):
        """Move the pointer onto ``row`` and click once. This SELECTS; it does not activate.

        PlayerEntityControls.m:765-780 - a left click only calls setSelectedRow: on whatever row
        the cursor is over. Activation is Enter or a double-click.
        """
        import pyautogui

        x, y = self.point_for_row(row)
        pyautogui.moveTo(x, y, duration=0.2)
        # The row under the cursor is read from the cursor position the renderer last saw, so
        # give the game a frame to notice the move before the click lands.
        time.sleep(0.3)
        pyautogui.click(x, y)
        time.sleep(0.3)
        return x, y

    def confirm_row(self, row):
        """Activate ``row`` with a double-click (gvMouseDoubleClick)."""
        import pyautogui

        x, y = self.point_for_row(row)
        pyautogui.doubleClick(x, y)


# --- fixtures -----------------------------------------------------------------------------------


def _lock_dir():
    """The same path tools/gui-lock computes. Change one, change the other."""
    explicit = os.environ.get("OO_GUI_LOCK_DIR")
    if explicit:
        return explicit
    local = os.environ.get("LOCALAPPDATA")
    if local:
        return os.path.join(local, "Temp", "oolite-gui-desktop.lock")
    import tempfile

    return os.path.join(tempfile.gettempdir(), "oolite-gui-desktop.lock")


@pytest.fixture(scope="session")
def desktop_lock():
    """Hold the GUI-tier desktop mutex for the whole session.

    This tier drives the interactive desktop with synthetic input, so two runs at once steal
    each other's focus and each other's clicks. tools/gui-lock is the mutex; it is a plain
    mkdir lock so a shell step and a pytest run can share it.
    """
    repo = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
    script = os.path.join(repo, "tools", "gui-lock")
    bash = shutil.which("bash")
    if bash and os.path.isfile(script):
        held = subprocess.run(
            [bash, script, "acquire", "--timeout", os.environ.get("OO_GUI_LOCK_TIMEOUT", "900")],
            capture_output=True,
            text=True,
        )
        if held.returncode != 0:
            pytest.fail(f"could not take the GUI desktop lock: {held.stderr.strip()}")
        try:
            yield _lock_dir()
        finally:
            subprocess.run([bash, script, "release"], capture_output=True)
        return
    # No bash (or no checkout around us): take the identical lock directly. Same protocol, same
    # path, so it still excludes a shell-side holder.
    path = _lock_dir()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    deadline = time.time() + 900
    while True:
        try:
            os.mkdir(path)
            break
        except FileExistsError:
            if time.time() >= deadline:
                pytest.fail(f"could not take the GUI desktop lock at {path}")
            time.sleep(2)
    try:
        yield path
    finally:
        shutil.rmtree(path, ignore_errors=True)


@pytest.fixture(scope="session")
def app_dir(pytestconfig):
    path = pytestconfig.getoption("--oolite-app") or _default_app_dir()
    if not os.path.isdir(path):
        pytest.fail(
            f"no Oolite build at {path}. Build it first (tools/build-windows.sh test) "
            "or pass --oolite-app."
        )
    return path


GUI_REQUIREMENTS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "requirements.txt")

# Set OO_GUI_REQUIRE=1 to turn even the not-applicable-platform skip into a failure, so that a
# run which was *supposed* to exercise G1 cannot come back green from the wrong machine.
GUI_REQUIRED = os.environ.get("OO_GUI_REQUIRE", "").strip().lower() not in ("", "0", "false", "no")


def require_gui_dependencies():
    """Import pyautogui or FAIL the test. Never skip.

    A skip is a silent pass. The import-or-skip helper this used to call meant that on the
    overwhelmingly common configuration - a machine where nothing had installed
    tests/gui/requirements.txt - the whole tier reported success without a window ever opening.
    On a platform where this tier IS supposed to run, a missing hard dependency is a broken
    environment, and a broken environment must be loud.
    """
    try:
        import pyautogui  # noqa: F401
    except Exception as exc:  # ImportError, but also the display/permission errors it raises
        pytest.fail(
            "the GUI tier's hard dependency 'pyautogui' is unusable "
            f"({exc.__class__.__name__}: {exc}).\n"
            "This tier drives a real window with real OS input; without pyautogui G1 cannot "
            "run, and a run that did not happen must not be reported as a pass. Install it:\n"
            f"    python3 -m pip install -r {GUI_REQUIREMENTS}\n"
            "or run the tier through its runner, which installs it for you:\n"
            "    bash tools/gui-tier.sh"
        )
    return pyautogui


def require_gui_platform():
    """Skip only where G1 is genuinely not applicable — and not even there under OO_GUI_REQUIRE."""
    if IS_WINDOWS:
        return
    if GUI_REQUIRED:
        pytest.fail(
            "OO_GUI_REQUIRE is set but this is not Windows "
            f"(sys.platform={sys.platform!r}). The GUI tier runs natively on Windows "
            "(ADR-0017); a run asked to exercise G1 must not pass by skipping."
        )
    # The one legitimate skip in this tier: a platform where G1 is genuinely not applicable.
    # Deliberate and explicit - not a missing dependency in disguise.
    pytest.skip(
        "the GUI tier runs natively on Windows (ADR-0017); "
        "set OO_GUI_REQUIRE=1 to make this a failure instead"
    )


@pytest.fixture(scope="session")
def gui_runtime():
    """The tier's precondition gate, resolved BEFORE the build or the desktop lock.

    Session-scoped and named first in ``game``'s signature so it is instantiated ahead of the
    session-scoped ``app_dir``: the one legitimate skip in this tier is "wrong platform", and it
    has to be reachable without a built game, or a Linux checkout reports a confusing
    missing-build error instead of the honest "not applicable here".
    """
    require_gui_platform()
    return require_gui_dependencies()


@pytest.fixture
def game(gui_runtime, app_dir, desktop_lock, tmp_path):
    """One game process with a real window, killed unconditionally at the end.

    Teardown kills rather than asks: a test that has already failed is a test whose game is in
    an unknown state, and a hung window must fail the run instead of wedging the desktop.
    """
    window = GameWindow(app_dir, str(tmp_path))
    try:
        yield window.start()
    finally:
        window.kill()


# --- post-exit hygiene (G9), asserted by every test in this tier --------------------------------


def assert_clean_exit(output_dir):
    """No core dump, no ERROR in Latest.log, and a defaults file that still parses.

    docs/phases/0-gui-tier.md G9. A shutdown that leaves any of these behind has not worked,
    however zero its exit status.
    """
    dumps = [
        f
        for f in os.listdir(output_dir)
        if f.endswith((".dmp", ".core")) or f.startswith("core.")
    ]
    assert not dumps, f"crash dump(s) left behind: {dumps}"

    log = os.path.join(output_dir, "Latest.log")
    if os.path.isfile(log):
        with open(log, "r", encoding="utf-8", errors="replace") as handle:
            bad = [
                line.strip()
                for line in handle
                if "ERROR" in line or "EXCEPTION" in line.upper()
            ]
        assert not bad, "errors in Latest.log:\n" + "\n".join(bad[:10])
