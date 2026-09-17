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
import platform
import random
import shutil
import subprocess
import sys
import time
import warnings

import pytest

IS_WINDOWS = sys.platform == "win32" or os.name == "nt"

if IS_WINDOWS:
    # RECT/POINT and ctypes.windll exist only here. The module must still IMPORT elsewhere so
    # that `pytest --collect-only` works on any platform; the fixtures skip instead.
    import ctypes.wintypes  # noqa: F401


# --- DPI awareness ------------------------------------------------------------------------------
#
# Oolite ships a manifest that declares PerMonitorV2 (src/SDL/OOResourcesWin/oolite.exe.manifest:
# 34-35), so the game's window lives in PHYSICAL pixels. A python.exe that has not declared
# awareness is DPI-*virtualised*: GetClientRect and ClientToScreen hand it logical pixels, and
# SendInput takes logical pixels too. At 100% scaling logical == physical and nothing shows; at
# 125% or 150% every coordinate this file computes is off by the scale factor, so the click lands
# on the wrong row or outside the window entirely and the game simply keeps running.
#
# That is the whole of the "passed for the implementer, failed for the reviewer, identical
# coordinate maths" failure: it is not flake, it is the test process and the game disagreeing
# about what a pixel is. Matching the game's awareness is what makes the two agree, so this runs
# at import - before pyautogui, and before any rect is read.
DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 = ctypes.c_void_p(-4) if IS_WINDOWS else None


# GetProcessDpiAwareness values (PROCESS_DPI_AWARENESS). The game is PerMonitorV2 by manifest,
# so only PER_MONITOR is a match: see why SYSTEM is NOT good enough in
# assert_dpi_awareness_matches_game.
DPI_UNAWARE = 0
DPI_SYSTEM_AWARE = 1
DPI_PER_MONITOR_AWARE = 2


def _become_per_monitor_dpi_aware():
    """Declare PerMonitorV2, matching the game. Returns True if this process is now PER_MONITOR.

    Every call's return is CHECKED rather than assumed: SetProcessDpiAwarenessContext is refused
    (ERROR_ACCESS_DENIED) for a process whose awareness is already set - by a manifest, by an
    embedding host, or by an earlier import - and a silently refused call would leave the process
    computing virtualised coordinates while this file reported success. The return is reported to
    the caller and the real, observed state is re-read from the OS below; the tests assert on that
    observed state, never on the request having been made.
    """
    if not IS_WINDOWS:
        return False
    user32 = ctypes.windll.user32
    if hasattr(user32, "SetProcessDpiAwarenessContext"):
        # Without argtypes ctypes passes the context as a 32-bit int and the call fails on win64.
        user32.SetProcessDpiAwarenessContext.argtypes = [ctypes.c_void_p]
        user32.SetProcessDpiAwarenessContext.restype = ctypes.c_bool
        _become_per_monitor_dpi_aware.requested = bool(
            user32.SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)
        )
        _become_per_monitor_dpi_aware.error = (
            0 if _become_per_monitor_dpi_aware.requested else ctypes.get_last_error()
        )
    elif hasattr(ctypes.windll, "shcore"):
        # 8.1 .. 10-1607: 2 == PROCESS_PER_MONITOR_DPI_AWARE. S_OK is 0; E_ACCESSDENIED means an
        # awareness was already set. The result is recorded, not swallowed.
        try:
            hresult = ctypes.windll.shcore.SetProcessDpiAwareness(DPI_PER_MONITOR_AWARE)
            _become_per_monitor_dpi_aware.requested = hresult == 0
            _become_per_monitor_dpi_aware.error = hresult
        except OSError as exc:
            _become_per_monitor_dpi_aware.requested = False
            _become_per_monitor_dpi_aware.error = repr(exc)
    else:
        # Pre-8.1 can only ever reach SYSTEM. That is recorded honestly so the assert below can
        # say so, rather than being quietly accepted as if it matched the game.
        _become_per_monitor_dpi_aware.requested = bool(user32.SetProcessDPIAware())
        _become_per_monitor_dpi_aware.error = "SetProcessDPIAware can only reach SYSTEM awareness"
    return _process_dpi_awareness() == DPI_PER_MONITOR_AWARE


_become_per_monitor_dpi_aware.requested = None
_become_per_monitor_dpi_aware.error = None


def _process_dpi_awareness():
    """0 = UNAWARE (coordinates are virtualised), 1 = SYSTEM, 2 = PER_MONITOR."""
    awareness = ctypes.c_int(0)
    ctypes.windll.shcore.GetProcessDpiAwareness(None, ctypes.byref(awareness))
    return awareness.value


if IS_WINDOWS:
    _become_per_monitor_dpi_aware()


def assert_dpi_awareness_matches_game():
    """Fail loudly unless this process is PER_MONITOR aware, exactly like the game.

    Oolite's manifest declares PerMonitorV2 (src/SDL/OOResourcesWin/oolite.exe.manifest:34-35), so
    its window is reported in PHYSICAL pixels on EVERY monitor.

    SYSTEM awareness (1) is NOT a match and must not pass. A system-aware process is told the
    primary monitor's DPI for the whole desktop, so on any monitor whose scaling differs from the
    primary's it is still handed VIRTUALISED coordinates by GetClientRect/ClientToScreen and still
    aims SendInput in them - the precise mismatch this function is named for. An assert of
    `awareness != 0` would pass in exactly the case the fix exists to prevent: awareness already
    set to SYSTEM by an earlier caller, so SetProcessDpiAwarenessContext is refused.
    """
    assert IS_WINDOWS, "DPI awareness is a Windows concept"
    awareness = _process_dpi_awareness()
    assert awareness == DPI_PER_MONITOR_AWARE, (
        f"this process reports DPI awareness {awareness} "
        f"({ {0: 'UNAWARE', 1: 'SYSTEM', 2: 'PER_MONITOR'}.get(awareness, 'unknown') }), but "
        "Oolite is PerMonitorV2 by manifest and its window is in PHYSICAL pixels. UNAWARE is "
        "virtualised everywhere; SYSTEM is virtualised on every monitor whose scaling differs "
        "from the primary's. Either way every row point computed here is wrong by the scale "
        "factor and the confirm click misses ` Exit Game ` while the maths still looks perfect.\n"
        f"The declaration at import {'succeeded' if _become_per_monitor_dpi_aware.requested else 'was REFUSED'}"
        f" (error {_become_per_monitor_dpi_aware.error!r}); an awareness already set by a "
        "manifest or an embedding host cannot be changed, so run this tier from a plain "
        "python.exe."
    )

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
# Taking the foreground is a request Windows can refuse (see GameWindow.focus); retry for this
# long before declaring the desktop unusable.
FOCUS_TIMEOUT_SECONDS = float(os.environ.get("OO_GUI_FOCUS_TIMEOUT", "15"))
# Comfortably inside MOUSE_DOUBLE_CLICK_INTERVAL (0.40s, src/SDL/MyOpenGLView.h:59): two clicks
# further apart than that are two single clicks to the game, and never activate a row.
DOUBLE_CLICK_INTERVAL_SECONDS = 0.05

# Prefixes a failure caused by the DESKTOP being unusable for GUI tests rather than by the game
# being broken. An operator (and tools/gui-tier.sh) must be able to tell the two apart at a
# glance: "G1 is broken" and "something elevated is sitting on your foreground" call for
# completely different responses, and reporting the second as the first is how a real regression
# gets ignored. Deliberately NOT a skip - a silent pass is what bead oo-7by1 just removed.
DESKTOP_UNUSABLE_MARKER = "GUI TIER PRECONDITION FAILED"

# How every GUI-tier launch is spelled. MyOpenGLView.m:363 matches the splash flag by exact
# ``isEqual:`` against -nosplash / --nosplash only, so any other spelling (a hyphen between "no"
# and "splash", say) is silently ignored and the splash runs; -windowed is matched at :1358 and
# is correct as written. tools/check-splash-off.py imports this list so the behavioural check can
# never drift from what the tier actually runs.
LAUNCH_ARGS = ["-nosplash", "-windowed"]


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


def _native_path(path):
    """Turn a git-for-Windows MSYS path (``/c/Users/...``) into one Python can open.

    Git run from an MSYS shell answers ``rev-parse`` in MSYS form even with
    ``--path-format=absolute``; ``os.path.isdir`` on that string is always False, which would
    silently defeat the fallback below rather than failing loudly.
    """
    if IS_WINDOWS and len(path) > 2 and path[0] == "/" and path[2] in "/\\" and path[1].isalpha():
        return f"{path[1].upper()}:/{path[3:]}"
    return path


def _default_app_dir():
    """Where oolite.app is, for a checkout that may not be the one holding the build.

    ``build/`` is gitignored (upstream/oolite/.gitignore:25), so a fresh worktree - the
    orchestrator's per-bead worktrees, and the detached checkout accept.sh merges into - contains
    the tests but no binary. Falling back to the main checkout's build makes the real G1 test
    runnable from those worktrees instead of being deselected, which is the failure that put this
    tier's only meaningful test outside its own acceptance. ``--oolite-app``/``$OO_APP_DIR`` still
    win, so a caller can always point somewhere else.
    """
    here = os.path.dirname(os.path.abspath(__file__))
    oolite = os.path.abspath(os.path.join(here, "..", ".."))
    local = os.path.join(oolite, "build", "meson_test", "oolite.app")
    if os.path.isdir(local):
        return local
    # A linked worktree's .git is a file pointing at the main checkout; its common dir is the
    # main repository's .git, whose parent is the checkout that holds the build.
    try:
        common = subprocess.run(
            ["git", "-C", oolite, "rev-parse", "--path-format=absolute", "--git-common-dir"],
            capture_output=True,
            text=True,
            timeout=30,
        )
    except (OSError, subprocess.SubprocessError):
        return local
    if common.returncode == 0 and common.stdout.strip():
        main_checkout = os.path.dirname(_native_path(common.stdout.strip()))
        shared = os.path.join(
            main_checkout, "upstream", "oolite", "build", "meson_test", "oolite.app"
        )
        if os.path.isdir(shared):
            return shared
    return local


def pytest_addoption(parser):
    parser.addoption(
        "--oolite-app",
        action="store",
        default=os.environ.get("OO_APP_DIR", ""),
        help="Path to oolite.app (default: $OO_APP_DIR, else the test build in this checkout)",
    )


def splash_evidence(log_text):
    """``(surface_line, loading_line, startup_line)`` - 1-based line numbers, ``None`` if absent.

    * ``surface_line``  - first ``display.initGL`` "Requested a new surface of W x H, windowed".
    * ``loading_line``  - first line of the resource-loading phase (``shipData.load.begin``,
      or ``searchPaths.dumpAll`` which immediately precedes it).
    * ``startup_line``  - the ``startup.complete`` line.

    Where ``surface_line`` falls RELATIVE TO ``loading_line`` is the runtime observable that
    distinguishes a splash-free launch from a splashed one.
    """
    surface = loading = startup = None
    for number, line in enumerate(log_text.splitlines(), 1):
        if surface is None and "Requested a new surface of" in line and "windowed" in line:
            surface = number
        if loading is None and ("shipData.load.begin" in line or "searchPaths.dumpAll" in line):
            loading = number
        if startup is None and "startup.complete" in line:
            startup = number
    return surface, loading, startup


def assert_splash_screen_is_off(log_text, log_path):
    """Fail unless the GL surface was created BEFORE resource loading started.

    Whether the splash ran is not visible in the spelling of the launch flag - a misspelled
    flag is silently ignored (MyOpenGLView.m:363 matches ``-nosplash``/``--nosplash`` by exact
    ``isEqual:``) - but it IS visible in the log's ordering:

    * splash OFF - MyOpenGLView.m:431 takes the ``if (!showSplashScreen)`` branch and calls
      ``initialiseGLWithSize:`` at :434 during ``-init``, i.e. BEFORE any resource loading;
    * splash ON  - that block is skipped and the call is deferred to :507 inside
      ``endSplashScreen``, which GameController.m:313 fires at the END of startup, after
      Universe init and loadPlayerIfRequired.

    Measured on both paths: splash off puts "Requested a new surface of 960 x 720, windowed"
    at log line 20 with ``shipData.load.begin`` at 32; splash on puts the same surface line at
    39, i.e. AFTER loading. Note the surface line still precedes ``startup.complete`` on both
    paths (39 vs 41 with the splash on), so "before startup.complete" is NOT the discriminator
    - "before resource loading" is.

    logcontrol.plist:131 enables ``display.initGL`` by default, so the line is in every log.
    This gates the actual defect (the splash running, and with it a moving target for every
    pinned-window coordinate) rather than the spelling of the flag.
    """
    surface, loading, startup = splash_evidence(log_text)
    assert startup is not None, f"no startup.complete line in {log_path}"
    assert loading is not None, (
        f"no resource-loading marker (shipData.load.begin / searchPaths.dumpAll) in {log_path}"
    )
    assert surface is not None, (
        "the splash screen ran: no 'Requested a new surface of ... windowed' line at all "
        f"in {log_path}"
    )
    assert surface < loading, (
        f"the splash screen ran: the GL surface was created at log line {surface}, AFTER "
        f"resource loading began at line {loading} (startup.complete at {startup}) in "
        f"{log_path}. That is the deferred endSplashScreen path (MyOpenGLView.m:507), so the "
        "no-splash flag did not take effect."
    )
    return surface, loading, startup


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
        # Before a single coordinate is read: this process must measure pixels the way the game
        # does, or every point computed below is silently wrong on a scaled display.
        assert_dpi_awareness_matches_game()
        self._park_software_gl()
        self.proc = subprocess.Popen(
            [path] + LAUNCH_ARGS,
            cwd=self.app_dir,
            env=self._env(),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        # EVERYTHING after the Popen must be unwound if it raises. These steps can all fail -
        # _await_startup_complete, _await_window and focus() all call pytest.fail - and a failure
        # here leaves a LIVE oolite.exe behind unless it is killed on the way out: the fixture's
        # teardown only runs once `yield window.start()` has been reached, which by definition it
        # has not. Such an orphan is not merely untidy. _pin_window parks every instance at
        # exactly (0,0) at the same client size, so the orphan covers the NEXT run's window pixel
        # for pixel and silently eats its clicks while the new window still owns the foreground -
        # the third failure mode, see assert_click_point_is_ours. One failure would therefore
        # poison every subsequent run on the machine.
        try:
            self._await_startup_complete(READY_TIMEOUT_SECONDS)
            self.hwnd = self._await_window(30)
            self._pin_window(*PINNED_CLIENT_SIZE)
            self.focus()
            time.sleep(SETTLE_SECONDS)
        except BaseException:
            # BaseException, not Exception: pytest.fail raises Failed, which derives from
            # BaseException, and that is the single most likely way to get here.
            self.kill()
            raise
        return self

    def kill(self):
        """Kill the game and undo the Mesa parking. Safe to call twice, and on a failed start().

        Must never raise: it runs on the failure path in start() and in fixture teardown, where
        an exception would mask the real error AND still leave the process behind.
        """
        try:
            if self.proc is not None and self.proc.poll() is None:
                self.proc.kill()
                try:
                    self.proc.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    # kill() is SIGKILL/TerminateProcess, so a timeout here means the OS has not
                    # reaped it yet rather than that it survived - but say so, because a survivor
                    # would occlude the next run's clicks.
                    print(
                        f"WARNING: oolite.exe pid {self.proc.pid} did not exit within 10s of "
                        "being killed; a survivor will occlude the next run's click point",
                        file=sys.stderr,
                    )
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
                    text = handle.read()
                if "startup.complete" in text:
                    # Readiness and the splash check read the SAME line pair, so assert it
                    # here: a launch whose splash ran has pinned the wrong window already.
                    assert_splash_screen_is_off(text, log)
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

    def _integrity_level(self, pid):
        """The process's mandatory integrity level, or None if it cannot be read.

        A medium-integrity process cannot read a high-integrity process's token, so None is
        itself evidence of a higher-integrity target: OpenProcess/OpenProcessToken fail with
        ERROR_ACCESS_DENIED across the UIPI boundary.
        """
        kernel32 = ctypes.windll.kernel32
        advapi32 = ctypes.windll.advapi32
        advapi32.GetSidSubAuthorityCount.restype = ctypes.POINTER(ctypes.c_ubyte)
        advapi32.GetSidSubAuthorityCount.argtypes = [ctypes.c_void_p]
        advapi32.GetSidSubAuthority.restype = ctypes.POINTER(ctypes.c_ulong)
        advapi32.GetSidSubAuthority.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
        kernel32.OpenProcess.restype = ctypes.wintypes.HANDLE
        handle = kernel32.OpenProcess(0x1000, False, pid)  # QUERY_LIMITED_INFORMATION
        if not handle:
            return None
        try:
            token = ctypes.wintypes.HANDLE()
            if not advapi32.OpenProcessToken(handle, 0x0008, ctypes.byref(token)):  # TOKEN_QUERY
                return None
            size = ctypes.wintypes.DWORD()
            advapi32.GetTokenInformation(token, 25, None, 0, ctypes.byref(size))
            buffer = ctypes.create_string_buffer(size.value)
            if not advapi32.GetTokenInformation(token, 25, buffer, size.value, ctypes.byref(size)):
                return None
            sid = ctypes.cast(buffer, ctypes.POINTER(ctypes.c_void_p))[0]
            count = advapi32.GetSidSubAuthorityCount(sid)[0]
            return advapi32.GetSidSubAuthority(sid, count - 1)[0]
        finally:
            kernel32.CloseHandle(handle)

    def _foreground_is_untakeable(self):
        """Is the current foreground owned by a process we are forbidden to steal it from?

        AttachThreadInput - the whole basis of focus() below - is refused with
        ERROR_ACCESS_DENIED across the UIPI/integrity boundary, so when an ELEVATED window
        (Task Manager started as administrator is the everyday example) owns the foreground, no
        amount of retrying can ever succeed. Distinguishing that case matters: it is
        "your desktop cannot run GUI tests right now", not "G1 is broken", and an operator who
        cannot tell the two apart will go looking for a bug in the game.

        Returns None when the foreground is takeable, or a description of the blocker.
        """
        user32 = ctypes.windll.user32
        kernel32 = ctypes.windll.kernel32
        foreground = user32.GetForegroundWindow()
        if not foreground or foreground == self.hwnd:
            return None
        pid = ctypes.c_ulong()
        thread = user32.GetWindowThreadProcessId(foreground, ctypes.byref(pid))
        our_thread = kernel32.GetCurrentThreadId()
        # The direct evidence: can we attach to its input queue at all?
        if thread and thread != our_thread:
            if user32.AttachThreadInput(our_thread, thread, True):
                user32.AttachThreadInput(our_thread, thread, False)
                return None
            if kernel32.GetLastError() != 5:  # anything but ACCESS_DENIED is a transient refusal
                return None
        ours = self._integrity_level(os.getpid())
        theirs = self._integrity_level(pid.value)
        title = ctypes.create_unicode_buffer(256)
        user32.GetWindowTextW(foreground, title, 256)
        cls = ctypes.create_unicode_buffer(256)
        user32.GetClassNameW(foreground, cls, 256)
        return (
            f"hwnd {foreground} (class {cls.value!r}, title {title.value!r}, pid {pid.value}) "
            f"refuses AttachThreadInput with ERROR_ACCESS_DENIED; its integrity level is "
            f"{theirs!r} against our {ours!r} (0x3000 = High/elevated, 0x2000 = Medium)"
        )

    def focus(self):
        """Make the game window the foreground window, and VERIFY that it worked.

        SetForegroundWindow is not a command, it is a request: Windows refuses it from a process
        that does not already own the foreground, and this desktop sets
        SPI_GETFOREGROUNDLOCKTIMEOUT to 0x7FFFFFFF, so the refusal is permanent and silent - the
        call returns 0 and merely flashes the taskbar. A test that ignores that return clicks at
        a correct coordinate on a window that is not accepting input, which looks exactly like a
        coordinate bug.

        AttachThreadInput to the current foreground thread lifts the restriction for the duration
        (the two threads share an input queue, so we count as the foreground for the call), which
        is the documented way to do this. It is attempted repeatedly and then asserted, because
        an unfocused window makes every later assertion in this tier meaningless.

        The one case retrying cannot fix is an ELEVATED foreground owner: AttachThreadInput does
        not cross the UIPI boundary, so the loop would spin out its whole timeout and then report
        a failure indistinguishable from a broken click. That case is detected and reported
        separately - see _foreground_is_untakeable and assert_desktop_can_run_gui_tests.
        """
        user32 = ctypes.windll.user32
        kernel32 = ctypes.windll.kernel32
        user32.ShowWindow(self.hwnd, 9)  # SW_RESTORE
        target_thread = user32.GetWindowThreadProcessId(self.hwnd, None)
        deadline = time.time() + FOCUS_TIMEOUT_SECONDS
        while time.time() < deadline:
            foreground = user32.GetForegroundWindow()
            if foreground == self.hwnd:
                time.sleep(0.2)
                return
            our_thread = kernel32.GetCurrentThreadId()
            fg_thread = user32.GetWindowThreadProcessId(foreground, None) if foreground else 0
            attached = []
            for thread in (fg_thread, target_thread):
                if thread and thread != our_thread and user32.AttachThreadInput(our_thread, thread, True):
                    attached.append(thread)
            try:
                user32.BringWindowToTop(self.hwnd)
                user32.SetForegroundWindow(self.hwnd)
                user32.SetActiveWindow(self.hwnd)
            finally:
                for thread in attached:
                    user32.AttachThreadInput(our_thread, thread, False)
            time.sleep(0.3)
        blocker = self._foreground_is_untakeable()
        if blocker:
            pytest.fail(
                f"{DESKTOP_UNUSABLE_MARKER}: an elevated (higher-integrity) window owns the "
                f"foreground and Windows forbids this process from taking it.\n  {blocker}\n"
                "This is NOT a G1 failure and says nothing about the game: AttachThreadInput "
                "cannot cross the UIPI boundary, so no retry can ever succeed while that window "
                "is foreground. Close or minimise it (an elevated Task Manager is the usual "
                "culprit) and re-run. tools/gui-tier.sh checks this precondition before it "
                "starts, so the tier reports it up front rather than as a mystery click failure."
            )
        pytest.fail(
            f"could not give the Oolite window (hwnd {self.hwnd}) the foreground within "
            f"{FOCUS_TIMEOUT_SECONDS}s; foreground is hwnd {user32.GetForegroundWindow()}. "
            "Synthetic clicks go to whatever is focused, so this tier cannot run on a desktop "
            "whose foreground it cannot take (a screen locked or in use - ADR-0017)."
        )

    def assert_focused(self):
        """The window still owns the foreground. Checked immediately before every click."""
        foreground = ctypes.windll.user32.GetForegroundWindow()
        assert foreground == self.hwnd, (
            f"the Oolite window lost the foreground before a click (foreground is hwnd "
            f"{foreground}, game is {self.hwnd}); the click would have gone to another window"
        )

    def assert_click_point_is_ours(self, x, y):
        """The window UNDER the click point is ours - which is not implied by owning the focus.

        THE THIRD FAILURE MODE. Foreground and Z-ORDER are different things, and a synthetic
        click made with mouse_event (which is what pyautogui uses - _pyautogui_win.py:_click) is
        delivered BY POSITION to the topmost window at that point, exactly like a physical click.
        It does not go to the foreground window. So a window that sits ABOVE the game at the
        click point swallows the click while GetForegroundWindow() still answers with the game's
        hwnd and assert_focused() still passes - a correctly placed, correctly timed double-click
        on a correctly focused window that never reaches the game.

        The occluder this tier produces for itself is an ORPHANED oolite.exe from an earlier run
        that died inside start(): _pin_window puts every instance at exactly (0,0) at the same
        960x720 client size, so an orphan covers the new window's rows pixel for pixel, is the
        same class (SDL_app), and - being on the start screen itself - silently consumes the
        click. Measured directly: with an orphan present, GetForegroundWindow() == our hwnd while
        WindowFromPoint(488,727) returned the ORPHAN's hwnd. The leak that creates such orphans is
        fixed in the ``game`` fixture; this assert is what makes the condition loud instead of
        looking like a coordinate bug if it ever arises another way.
        """
        user32 = ctypes.windll.user32
        under = user32.WindowFromPoint(ctypes.wintypes.POINT(x, y))
        root = user32.GetAncestor(under, 2) or under  # GA_ROOT: children belong to their frame
        if root == self.hwnd:
            return
        pid = ctypes.c_ulong()
        user32.GetWindowThreadProcessId(root, ctypes.byref(pid))
        cls = ctypes.create_unicode_buffer(256)
        user32.GetClassNameW(root, cls, 256)
        title = ctypes.create_unicode_buffer(256)
        user32.GetWindowTextW(root, title, 256)
        same_binary = cls.value == "SDL_app"
        pytest.fail(
            f"the click point {(x, y)} is OCCLUDED: the topmost window there is hwnd {root} "
            f"(class {cls.value!r}, title {title.value!r}, pid {pid.value}), not the game's hwnd "
            f"{self.hwnd}. The game still owns the FOREGROUND, but a synthetic click is "
            "delivered by position to whatever is on top at that point, so this click would "
            "have been swallowed and the game would simply keep running.\n"
            + (
                "That window is another Oolite instance (class SDL_app) - almost certainly an "
                "orphan leaked by an earlier run that failed inside start(). Kill any stray "
                "oolite.exe and re-run."
                if same_binary
                else "Move or close that window; this tier needs the game's rows unobscured."
            )
        )

    # --- input --------------------------------------------------------------------------------

    def point_for_row(self, row):
        return row_to_point(row, self.client_rect())

    def select_row(self, row):
        """Move the pointer onto ``row`` and click once. This SELECTS; it does not activate.

        PlayerEntityControls.m:765-780 - a left click only calls setSelectedRow: on whatever row
        the cursor is over. Activation is Enter or a double-click.
        """
        import pyautogui

        self.focus()
        x, y = self.point_for_row(row)
        pyautogui.moveTo(x, y, duration=0.2)
        # The row under the cursor is read from the cursor position the renderer last saw, so
        # give the game a frame to notice the move before the click lands.
        time.sleep(0.3)
        self.assert_focused()
        self.assert_click_point_is_ours(x, y)
        pyautogui.click(x, y)
        time.sleep(0.3)
        return x, y

    def confirm_row(self, row):
        """Activate ``row`` with a double-click (gvMouseDoubleClick).

        The two clicks must be closer together than MOUSE_DOUBLE_CLICK_INTERVAL (0.40s,
        MyOpenGLView.h:59) or MyOpenGLView+Input.m:285-293 records two separate single clicks and
        never sets gvMouseDoubleClick, so pyautogui's inter-click interval is pinned rather than
        left at its default.
        """
        import pyautogui

        self.assert_focused()
        x, y = self.point_for_row(row)
        # Focus is not enough: the click goes to whatever is topmost AT THIS POINT. See
        # assert_click_point_is_ours - this is the third failure mode this bead was reworked for.
        self.assert_click_point_is_ours(x, y)
        pyautogui.doubleClick(x, y, interval=DOUBLE_CLICK_INTERVAL_SECONDS)



# --- fixtures -----------------------------------------------------------------------------------


def _lock_script():
    """Absolute path to tools/gui-lock, or None if there is no checkout around us."""
    repo = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
    script = os.path.join(repo, "tools", "gui-lock")
    return script if os.path.isfile(script) else None


def _lock_path():
    """The lock directory - the SAME string tools/gui-lock prints.

    Sameness is not promised, it is delegated: we ask the script. Two halves each applying
    "the same rules" is how this drifted before - the shell said ${TMPDIR:-/tmp}/... (an MSYS
    path) while python said tempfile.gettempdir() (a native path), so a shell holder and a
    pytest holder locked two different directories and the mutex silently stopped excluding.
    The bash-less fallback below repeats the rules only because it must, and normalises to the
    same native C:/... form the script emits via `cygpath -m`.
    """
    bash = shutil.which("bash")
    script = _lock_script()
    if bash and script:
        out = subprocess.run(
            [bash, script, "path"], capture_output=True, text=True
        )
        if out.returncode == 0 and out.stdout.strip():
            return out.stdout.strip()
    explicit = os.environ.get("OO_GUI_LOCK_DIR")
    if explicit:
        return _native(explicit)
    local = os.environ.get("LOCALAPPDATA")
    if local:
        return _native(os.path.join(local, "Temp", "oolite-gui-desktop.lock"))
    import tempfile

    return _native(os.path.join(tempfile.gettempdir(), "oolite-gui-desktop.lock"))


def _native(path):
    """Forward-slash native form, matching `cygpath -m` output on this machine."""
    return os.path.abspath(path).replace("\\", "/")


def _lock_owner():
    """This session's owner identity, passed explicitly to tools/gui-lock.

    Not left to the script's default: the script's fallback identity is "<host>:<PPID>", and a
    bash spawned by a *native* Windows python reports PPID=1, so every pytest session would
    claim the identity "<host>:1" and could release another session's lock. We pass our own pid
    in OO_GUI_LOCK_OWNER for both acquire and release, so the identity is ours and is stable
    across the two invocations.
    """
    explicit = os.environ.get("OO_GUI_LOCK_OWNER")
    if explicit:
        return explicit
    host = os.environ.get("HOSTNAME") or platform.node()
    return f"{host}:py{os.getpid()}"


def _lock_held_by(path):
    """The owner recorded in the lock directory, or None."""
    try:
        with open(os.path.join(path, "owner"), "r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
                if line.startswith("owner="):
                    return line[len("owner=") :].strip()
    except OSError:
        return None
    return None


def _lock_reclaim_stale(path, stale):
    """Atomically reclaim a stale lock directory, returning True only if WE now hold it.

    This is the same protocol as tools/gui-lock's reclaim_stale(), down to the gate directory
    name, so the two halves interlock rather than each reclaiming "their own way": a fallback
    session and a shell session racing the same stale lock still produce exactly one winner.

    The naive "if stale: rmtree; then mkdir" is a TOCTOU - two runs both judge the same
    directory stale and the loser's rmtree deletes the winner's freshly created lock, so both
    end up on the desktop. So we serialise reapers behind a short-lived ``<lock>.reap`` mkdir
    gate, RE-CHECK the age inside it, retire the stale directory with a single atomic rename,
    and only drop the gate once the new lock exists.
    """
    reap = path + ".reap"
    reap_stale = float(os.environ.get("OO_GUI_LOCK_REAP_STALE", "300"))
    try:
        if time.time() - os.path.getmtime(path) <= stale:
            return False
    except OSError:
        return False
    try:
        os.mkdir(reap)
    except FileExistsError:
        # A reaper died mid-reclaim? Retire the gate itself atomically; the rename has exactly
        # one winner, and that winner does not assume it holds the gate - it just retries.
        try:
            if time.time() - os.path.getmtime(reap) > reap_stale:
                dead = "%s.dead.%d.%d" % (reap, os.getpid(), random.randrange(1 << 30))
                os.rename(reap, dead)
                shutil.rmtree(dead, ignore_errors=True)
        except OSError:
            pass
        return False
    except OSError:
        return False
    try:
        if os.path.isdir(path):
            try:
                still_stale = time.time() - os.path.getmtime(path) > stale
            except OSError:
                still_stale = False
            if not still_stale:
                return False
            dead = "%s.stale.%d.%d" % (path, os.getpid(), random.randrange(1 << 30))
            try:
                os.rename(path, dead)
            except OSError:
                return False
            shutil.rmtree(dead, ignore_errors=True)
        try:
            os.mkdir(path)
        except OSError:
            return False
        return True
    finally:
        shutil.rmtree(reap, ignore_errors=True)


@pytest.fixture(scope="session")
def desktop_lock():
    """Hold the GUI-tier desktop mutex for the whole session.

    This tier drives the interactive desktop with synthetic input, so two runs at once steal
    each other's focus and each other's clicks. tools/gui-lock is the mutex; it is a plain
    mkdir lock so a shell step and a pytest run can share it.
    """
    script = _lock_script()
    bash = shutil.which("bash")
    me = _lock_owner()
    if bash and script:
        # OO_GUI_LOCK_OWNER is ours and is passed to BOTH calls, so release drops the lock this
        # session took and the script refuses it if some other run holds it.
        env = dict(os.environ, OO_GUI_LOCK_OWNER=me)
        held = subprocess.run(
            [bash, script, "acquire", "--timeout", os.environ.get("OO_GUI_LOCK_TIMEOUT", "900")],
            capture_output=True,
            text=True,
            env=env,
        )
        if held.returncode != 0:
            pytest.fail(f"could not take the GUI desktop lock: {held.stderr.strip()}")
        try:
            yield _lock_path()
        finally:
            dropped = subprocess.run(
                [bash, script, "release"], capture_output=True, text=True, env=env
            )
            if dropped.returncode != 0:
                warnings.warn(
                    f"gui-lock: release refused: {dropped.stderr.strip()}", stacklevel=1
                )
        return
    # No bash (or no checkout around us): take the identical lock directly. Same protocol, same
    # path, same ownership record, so it still excludes - and is still excluded by - a
    # shell-side holder.
    path = _lock_path()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    deadline = time.time() + float(os.environ.get("OO_GUI_LOCK_TIMEOUT", "900"))
    while True:
        got = False
        try:
            os.mkdir(path)
            got = True
        except FileExistsError:
            # Same stale rule as the script (OO_GUI_LOCK_STALE, age not liveness), so a
            # crashed holder does not wedge the tier for ever here either - but the reclaim is
            # ATOMIC (see _lock_reclaim_stale): an unconditional rmtree here would let two
            # sessions both judge one lock stale and both take the desktop.
            stale = float(os.environ.get("OO_GUI_LOCK_STALE", "1800"))
            got = _lock_reclaim_stale(path, stale)
        if got:
            with open(os.path.join(path, "owner"), "w", encoding="utf-8") as fh:
                fh.write(f"owner={me}\ninfo=python pid={os.getpid()} {time.strftime('%FT%T%z')}\n")
            break
        if time.time() >= deadline:
            pytest.fail(
                f"could not take the GUI desktop lock at {path}; "
                f"held by {_lock_held_by(path) or 'unknown'}"
            )
        time.sleep(2)
    try:
        yield path
    finally:
        # Ownership-checked, never an unconditional rmtree: a teardown that ran after some
        # other run had legitimately taken the lock would otherwise drop a live holder's lock
        # and put two processes on the desktop at once.
        holder = _lock_held_by(path)
        if holder == me:
            shutil.rmtree(path, ignore_errors=True)
        else:
            warnings.warn(
                f"gui-lock: not releasing {path}: held by {holder or 'unknown'}, we are {me}",
                stacklevel=1,
            )


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


def describe_untakeable_foreground():
    """Is an elevated window sitting on the foreground right now? Returns a reason, or None.

    The same UIPI check GameWindow._foreground_is_untakeable performs, but usable BEFORE a game
    exists, so the tier can report "this desktop cannot run GUI tests" as a precondition instead
    of as a 15-second timeout inside the first click. Cheap: one AttachThreadInput attempt.
    """
    if not IS_WINDOWS:
        return None
    user32 = ctypes.windll.user32
    kernel32 = ctypes.windll.kernel32
    foreground = user32.GetForegroundWindow()
    if not foreground:
        return None
    pid = ctypes.c_ulong()
    thread = user32.GetWindowThreadProcessId(foreground, ctypes.byref(pid))
    our_thread = kernel32.GetCurrentThreadId()
    if not thread or thread == our_thread:
        return None
    if user32.AttachThreadInput(our_thread, thread, True):
        user32.AttachThreadInput(our_thread, thread, False)
        return None
    if kernel32.GetLastError() != 5:  # ERROR_ACCESS_DENIED is the UIPI signature
        return None
    title = ctypes.create_unicode_buffer(256)
    user32.GetWindowTextW(foreground, title, 256)
    cls = ctypes.create_unicode_buffer(256)
    user32.GetClassNameW(foreground, cls, 256)
    return (
        f"hwnd {foreground} (class {cls.value!r}, title {title.value!r}, pid {pid.value}) owns "
        "the foreground and refuses AttachThreadInput with ERROR_ACCESS_DENIED, which means it "
        "runs at a higher integrity level (it is elevated) than this test process"
    )


def assert_desktop_can_run_gui_tests():
    """Refuse to start when the desktop is known to be unusable, and say so distinguishably.

    A gate that any single elevated window on the desktop can wedge is not a gate accept.sh can
    pass - but a SILENT PASS is not the answer either (that is exactly what bead oo-7by1 removed).
    So this fails, loudly, with DESKTOP_UNUSABLE_MARKER and the offending window named, up front
    and before a game is launched. The operator sees "your desktop is unusable for GUI tests"
    rather than "G1 is broken", which are the two things the reviewer could not tell apart.

    It is a FAILURE and not a skip on purpose: the condition is fixable in seconds (close the
    elevated window) and a run that reported success without exercising G1 would be a lie. It is
    reported BEFORE the run rather than 15 seconds into the first click so that the cause, not
    the symptom, is what lands in the log.
    """
    blocker = describe_untakeable_foreground()
    if blocker:
        pytest.fail(
            f"{DESKTOP_UNUSABLE_MARKER}: this desktop cannot run the GUI tier right now.\n"
            f"  {blocker}\n"
            "Synthetic input goes to the focused window, and Windows forbids a medium-integrity "
            "process from taking the foreground away from an elevated one - AttachThreadInput "
            "cannot cross the UIPI boundary, so no retry can ever succeed. NOTHING IS WRONG WITH "
            "THE GAME OR WITH G1; close or minimise that window and re-run. (An elevated Task "
            "Manager is the usual culprit.)"
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
    pyautogui = require_gui_dependencies()
    # Checked here, once per session, so an unusable desktop is reported as its own cause before
    # any game is launched rather than as a mysterious click failure 15s into the first test.
    assert_desktop_can_run_gui_tests()
    return pyautogui


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
