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

# --- Win32 signatures -------------------------------------------------------------------------
#
# EVERY Win32 function this tier calls is declared here, and the functions are reached through
# the module-level library handles below - never through ``ctypes.windll``.
#
# Why this table exists (bug oo-x2uy). A ctypes function object with no ``argtypes`` marshals a
# Python ``int`` argument as a 32-bit C ``int``, and with no ``restype`` it decodes the return
# value as a 32-bit signed ``int``. On 64-bit Windows an HWND is a 64-bit pointer-sized handle,
# so an undeclared call cannot carry one: a handle at or above 2**32 either raises
# ``ArgumentError: int too long to convert`` (current CPython) or is silently truncated to its
# low 32 bits (older CPython) - and an undeclared *return* of a handle is truncated and
# sign-extended with no error at all. The tier appeared to work only because Windows hands out
# small HWNDs most of the time; that is a coin toss, not a contract, and every GUI bead G2-G9
# inherits it.
#
# The table is a plain dict of TYPE NAMES rather than ctypes objects so that it can be imported
# and asserted on from any platform (see test_win32_declarations.py, which fails if a call site
# in this tier is missing from it).
#
# Format: "<library>.<function>": (restype name, [argtype names]).
WIN32_SIGNATURES = {
    "user32.EnumWindows": ("BOOL", ["WNDENUMPROC", "LPARAM"]),
    "user32.GetWindowThreadProcessId": ("DWORD", ["HWND", "LPDWORD"]),
    "user32.IsWindowVisible": ("BOOL", ["HWND"]),
    "user32.SendMessageTimeoutW": (
        "LRESULT",
        ["HWND", "UINT", "WPARAM", "LPARAM", "UINT", "UINT", "PDWORD_PTR"],
    ),
    "user32.GetWindowRect": ("BOOL", ["HWND", "LPRECT"]),
    "user32.GetClientRect": ("BOOL", ["HWND", "LPRECT"]),
    "user32.ClientToScreen": ("BOOL", ["HWND", "LPPOINT"]),
    "user32.SetWindowPos": ("BOOL", ["HWND", "HWND", "INT", "INT", "INT", "INT", "UINT"]),
    "user32.ShowWindow": ("BOOL", ["HWND", "INT"]),
    "user32.SetForegroundWindow": ("BOOL", ["HWND"]),
    # Foreground arbitration (GameWindow.focus / assert_focused / _foreground_is_untakeable).
    "user32.GetForegroundWindow": ("HWND", []),
    "user32.SetActiveWindow": ("HWND", ["HWND"]),
    "user32.BringWindowToTop": ("BOOL", ["HWND"]),
    "user32.AttachThreadInput": ("BOOL", ["DWORD", "DWORD", "BOOL"]),
    # Z-order probe (assert_click_point_is_ours). WindowFromPoint takes a POINT BY VALUE - an
    # 8-byte struct - which an undeclared call cannot pass correctly at all.
    "user32.WindowFromPoint": ("HWND", ["POINT"]),
    "user32.GetAncestor": ("HWND", ["HWND", "UINT"]),
    # Closing the window the way the title-bar X does (G3). PostMessageW takes WPARAM/LPARAM,
    # both pointer-sized: undeclared they narrow to 32 bits, and the HWND narrows with them, so
    # the message would be posted to a truncated handle - i.e. to nothing - and PostMessage would
    # report failure (or worse, succeed against an unrelated window).
    "user32.PostMessageW": ("BOOL", ["HWND", "UINT", "WPARAM", "LPARAM"]),
    # Naming the window that is in the way.
    "user32.GetWindowTextW": ("INT", ["HWND", "LPWSTR", "INT"]),
    "user32.GetClassNameW": ("INT", ["HWND", "LPWSTR", "INT"]),
    # DPI awareness, declared at import before any rect is read.
    "user32.SetProcessDpiAwarenessContext": ("BOOL", ["LPVOID"]),
    "user32.SetProcessDPIAware": ("BOOL", []),
    "shcore.SetProcessDpiAwareness": ("LONG", ["INT"]),
    "shcore.GetProcessDpiAwareness": ("LONG", ["HANDLE", "PINT"]),
    # Integrity levels, for telling "elevated window owns the desktop" from "G1 is broken".
    "kernel32.GetCurrentThreadId": ("DWORD", []),
    "kernel32.OpenProcess": ("HANDLE", ["DWORD", "BOOL", "DWORD"]),
    "advapi32.OpenProcessToken": ("BOOL", ["HANDLE", "DWORD", "PHANDLE"]),
    "advapi32.GetTokenInformation": ("BOOL", ["HANDLE", "INT", "LPVOID", "DWORD", "LPDWORD"]),
    "advapi32.GetSidSubAuthorityCount": ("PUCHAR", ["LPVOID"]),
    "advapi32.GetSidSubAuthority": ("LPDWORD", ["LPVOID", "DWORD"]),
    # The Tool Help process-table walk (surviving_game_processes). CreateToolhelp32Snapshot
    # RETURNS a HANDLE: undeclared, that 64-bit handle comes back truncated and sign-extended
    # through a 32-bit int, so the very first Process32First on it fails with
    # ERROR_INVALID_HANDLE - and the walk then reports "no survivors", which is the silent pass
    # this bead exists to remove. The snapshot handle is HANDLE for the same reason an HWND is
    # HWND: it is pointer-sized, and c_void_p/c_int would satisfy "has argtypes" while
    # reproducing the defect exactly.
    "kernel32.CreateToolhelp32Snapshot": ("HANDLE", ["DWORD", "DWORD"]),
    "kernel32.Process32First": ("BOOL", ["HANDLE", "LPPROCESSENTRY32"]),
    "kernel32.Process32Next": ("BOOL", ["HANDLE", "LPPROCESSENTRY32"]),
    "kernel32.CloseHandle": ("BOOL", ["HANDLE"]),
}

# Functions that do not exist on every supported Windows. Declaring them is conditional; CALLING
# them is already guarded by hasattr at the call site.
OPTIONAL_WIN32 = frozenset(
    {
        "user32.SetProcessDpiAwarenessContext",  # 10-1703 and later
        "shcore.SetProcessDpiAwareness",  # 8.1 and later
        "shcore.GetProcessDpiAwareness",  # 8.1 and later
    }
)

# The library handles. ``None`` off Windows: the module must still IMPORT everywhere so that
# `pytest --collect-only` and the offline guard tests work on any platform; the fixtures skip.
USER32 = None
SHCORE = None
KERNEL32 = None
ADVAPI32 = None
WNDENUMPROC = None
PROCESSENTRY32 = None

if IS_WINDOWS:
    # RECT/POINT and the Win32 libraries exist only here.
    from ctypes import wintypes

    # EnumWindows' callback. Declared with the real parameter types for the same reason as
    # everything else: an undeclared ``c_void_p`` HWND parameter is fine, but a declared one
    # documents the 64-bit width and keeps the table honest.
    WNDENUMPROC = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)

    class PROCESSENTRY32(ctypes.Structure):
        """tlhelp32.h's PROCESSENTRY32 (the ANSI form, matching Process32First/Next).

        Declared at module scope rather than inside the table reader so that the signature
        table can name a real ``POINTER(PROCESSENTRY32)`` - a bare ``c_void_p`` would let a
        caller pass any pointer at all, and dwSize is the only thing standing between a wrong
        structure layout and Process32First returning FALSE (i.e. "no processes", a pass).
        """

        _fields_ = [
            ("dwSize", wintypes.DWORD),
            ("cntUsage", wintypes.DWORD),
            ("th32ProcessID", wintypes.DWORD),
            ("th32DefaultHeapID", ctypes.POINTER(ctypes.c_ulong)),
            ("th32ModuleID", wintypes.DWORD),
            ("cntThreads", wintypes.DWORD),
            ("th32ParentProcessID", wintypes.DWORD),
            ("pcPriClassBase", ctypes.c_long),
            ("dwFlags", wintypes.DWORD),
            ("szExeFile", ctypes.c_char * 260),
        ]

    # The pointer-sized scalars ctypes.wintypes does not define. LRESULT and DWORD_PTR are
    # LONG_PTR/ULONG_PTR: 64 bits here, 32 bits on Win32, which is exactly the width that goes
    # wrong when nothing is declared.
    LRESULT = ctypes.c_ssize_t
    DWORD_PTR = ctypes.c_size_t

    _WIN32_TYPES = {
        "BOOL": wintypes.BOOL,
        "DWORD": wintypes.DWORD,
        "DWORD_PTR": DWORD_PTR,
        "HANDLE": wintypes.HANDLE,
        "HWND": wintypes.HWND,
        "INT": ctypes.c_int,
        "LONG": wintypes.LONG,
        "LPARAM": wintypes.LPARAM,
        "LPDWORD": ctypes.POINTER(wintypes.DWORD),
        "LPPOINT": ctypes.POINTER(wintypes.POINT),
        "LPPROCESSENTRY32": ctypes.POINTER(PROCESSENTRY32),
        "LPRECT": ctypes.POINTER(wintypes.RECT),
        "LPVOID": ctypes.c_void_p,
        "LPWSTR": wintypes.LPWSTR,
        "LRESULT": LRESULT,
        "PDWORD_PTR": ctypes.POINTER(DWORD_PTR),
        "PHANDLE": ctypes.POINTER(wintypes.HANDLE),
        "PINT": ctypes.POINTER(ctypes.c_int),
        "POINT": wintypes.POINT,
        "PUCHAR": ctypes.POINTER(ctypes.c_ubyte),
        "UINT": wintypes.UINT,
        "WNDENUMPROC": WNDENUMPROC,
        "WPARAM": wintypes.WPARAM,
    }

    def _declare_win32(libraries):
        """Stamp WIN32_SIGNATURES onto the real ctypes function objects.

        Driven off the table so the declarations and the guard test cannot drift apart.
        """
        for qualified, (restype, argtypes) in WIN32_SIGNATURES.items():
            library, _, function = qualified.partition(".")
            handle = libraries.get(library)
            if handle is None:
                # A library this Windows does not have (shcore before 8.1). Its call sites are
                # hasattr-guarded; an undeclarable signature must not break the import.
                if qualified in OPTIONAL_WIN32:
                    continue
                raise OSError(f"{library} is required by this tier but could not be loaded")
            try:
                func = getattr(handle, function)
            except AttributeError:
                if qualified in OPTIONAL_WIN32:
                    continue
                raise
            func.restype = _WIN32_TYPES[restype]
            func.argtypes = [_WIN32_TYPES[name] for name in argtypes]
        return libraries

    # Our OWN handles, not ``ctypes.windll.*``: windll hands out a process-wide cached
    # library whose function objects are shared with every other importer, so declaring
    # argtypes on it would mutate somebody else's calls. use_last_error gives us a
    # ctypes-private copy of GetLastError that a later Python call cannot clobber - and it is
    # the ONLY way ``ctypes.get_last_error()`` ever returns anything but 0, which is why the
    # DPI refusal below can report a real error code instead of a constant zero.
    USER32 = ctypes.WinDLL("user32", use_last_error=True)
    KERNEL32 = ctypes.WinDLL("kernel32", use_last_error=True)
    ADVAPI32 = ctypes.WinDLL("advapi32", use_last_error=True)
    try:
        SHCORE = ctypes.WinDLL("shcore", use_last_error=True)
    except OSError:  # pre-8.1: SetProcessDPIAware is all there is
        SHCORE = None
    _declare_win32(
        {"user32": USER32, "kernel32": KERNEL32, "advapi32": ADVAPI32, "shcore": SHCORE}
    )


def _win32_error(function):
    """The OSError for the last failed Win32 call, read from ctypes' private last-error slot."""
    return ctypes.WinError(ctypes.get_last_error(), f"{function} failed")


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

    The recorded ``error`` must be MEANINGFUL, not merely present. ``ctypes.get_last_error()``
    reads ctypes' private last-error slot, which is only ever populated for functions reached
    through a ``ctypes.WinDLL(..., use_last_error=True)`` handle: called on a function from the
    shared ``ctypes.windll`` cache it returns a constant 0, so a refusal would be reported as
    "REFUSED (error 0)" and tell the operator nothing. USER32 above IS such a handle, so the
    code below is the real ERROR_ACCESS_DENIED (5) on the refusal path. Measured: after a
    genuinely refused second call, SetProcessDpiAwarenessContext -> False and
    ``ctypes.get_last_error()`` -> 5.
    """
    if not IS_WINDOWS:
        return False
    if hasattr(USER32, "SetProcessDpiAwarenessContext"):
        ctypes.set_last_error(0)
        _become_per_monitor_dpi_aware.requested = bool(
            USER32.SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)
        )
        _become_per_monitor_dpi_aware.error = (
            0 if _become_per_monitor_dpi_aware.requested else ctypes.get_last_error()
        )
    elif SHCORE is not None and hasattr(SHCORE, "SetProcessDpiAwareness"):
        # 8.1 .. 10-1607: 2 == PROCESS_PER_MONITOR_DPI_AWARE. S_OK is 0; E_ACCESSDENIED means an
        # awareness was already set. The HRESULT is itself the error code, so it is recorded
        # directly rather than read from the last-error slot (which this API does not set).
        try:
            hresult = SHCORE.SetProcessDpiAwareness(DPI_PER_MONITOR_AWARE)
            _become_per_monitor_dpi_aware.requested = hresult == 0
            _become_per_monitor_dpi_aware.error = 0 if hresult == 0 else hresult
        except OSError as exc:
            _become_per_monitor_dpi_aware.requested = False
            _become_per_monitor_dpi_aware.error = repr(exc)
    else:
        # Pre-8.1 can only ever reach SYSTEM. That is recorded honestly so the assert below can
        # say so, rather than being quietly accepted as if it matched the game.
        _become_per_monitor_dpi_aware.requested = bool(USER32.SetProcessDPIAware())
        _become_per_monitor_dpi_aware.error = "SetProcessDPIAware can only reach SYSTEM awareness"
    return _process_dpi_awareness() == DPI_PER_MONITOR_AWARE


_become_per_monitor_dpi_aware.requested = None
_become_per_monitor_dpi_aware.error = None


def _process_dpi_awareness():
    """0 = UNAWARE (coordinates are virtualised), 1 = SYSTEM, 2 = PER_MONITOR."""
    awareness = ctypes.c_int(0)
    SHCORE.GetProcessDpiAwareness(None, ctypes.byref(awareness))
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

# The window message a title-bar X click ends up delivering (winuser.h). SDL's Win32 backend
# turns it into SDL_EVENT_QUIT, which is the event G3 exists to exercise; see
# GameWindow.close_window for why this and not a synthesised in-process SDL event.
WM_CLOSE = 0x0010


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
        # Filled in by start(): what the defaults files looked like BEFORE this run wrote
        # anything. assert_defaults_file_reparses needs it to tell "this run wrote the file"
        # from "a file is lying there from an earlier run" (oo-5rsa).
        self.defaults_launch_mark = None

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
        # BEFORE the process starts: record what is already on disk, so that after exit we can
        # tell a file THIS run wrote from one an earlier run left behind. app_dir is the
        # persistent build tree, so without this mark "the defaults file exists" is true
        # forever and the G9 defaults check cannot fail (oo-5rsa). Taken before Popen so no
        # write of ours can land inside the window between stat and launch; mtime granularity
        # is not a worry because the game runs for seconds (startup gate + SETTLE_SECONDS)
        # before it can possibly synchronize its defaults.
        self.defaults_launch_mark = defaults_write_mark(self.app_dir)
        self.proc = subprocess.Popen(
            [path] + LAUNCH_ARGS,
            cwd=self.app_dir,
            env=self._env(),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        # EVERYTHING after the Popen is unwound if it raises. These steps can all fail -
        # _await_startup_complete, _await_window and focus() all call pytest.fail - and the
        # process this method has already launched must not survive such a failure. This
        # try/except is BELT AND BRACES, not the only defence: measured on both trees, when
        # start() raises the exception propagates out through the ``yield window.start()``
        # expression inside the fixture generator and the ``finally: window.kill()`` in the
        # ``game`` fixture runs during the unwind, so the process was already being killed
        # without this. It stays because a killed-twice process is free and an orphaned
        # oolite.exe is not: _pin_window parks every instance at exactly (0,0) at the same
        # client size, so any surviving instance covers the NEXT run's window pixel for pixel
        # and silently eats its clicks (see assert_click_point_is_ours, which is the check that
        # makes that condition loud whatever its source).
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
        found = []
        pid = wintypes.DWORD()

        def visit(hwnd, _lparam):
            USER32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
            if pid.value == self.proc.pid and USER32.IsWindowVisible(hwnd):
                found.append(hwnd)
            return True

        USER32.EnumWindows(WNDENUMPROC(visit), 0)
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
        SMTO_ABORTIFHUNG = 0x0002
        WM_NULL = 0x0000
        deadline = time.time() + timeout
        while time.time() < deadline:
            if self.proc.poll() is not None:
                pytest.fail(
                    f"Oolite exited with {self.proc.returncode} before opening a window; "
                    f"see {self.output_dir}"
                )
            for hwnd in self._top_level_windows():
                result = DWORD_PTR()
                if USER32.SendMessageTimeoutW(
                    hwnd, WM_NULL, 0, 0, SMTO_ABORTIFHUNG, 2000, ctypes.byref(result)
                ):
                    return hwnd
            time.sleep(0.5)
        pytest.fail(f"Oolite did not service window messages within {timeout}s")

    def _pin_window(self, client_w, client_h):
        """Resize so the CLIENT area is exactly the pinned size, and park it at the top-left.

        The grid maths is in client pixels, so pinning the outer window instead would make the
        row points depend on the border and title-bar metrics of whoever's desktop this is.
        """
        user32 = USER32
        win = wintypes.RECT()
        cli = wintypes.RECT()
        if not user32.GetWindowRect(self.hwnd, ctypes.byref(win)):
            raise _win32_error("GetWindowRect")
        if not user32.GetClientRect(self.hwnd, ctypes.byref(cli)):
            raise _win32_error("GetClientRect")
        chrome_w = (win.right - win.left) - (cli.right - cli.left)
        chrome_h = (win.bottom - win.top) - (cli.bottom - cli.top)
        SWP_NOZORDER = 0x0004
        if not user32.SetWindowPos(
            self.hwnd, None, 0, 0, client_w + chrome_w, client_h + chrome_h, SWP_NOZORDER
        ):
            raise _win32_error("SetWindowPos")
        # The game only recomputes display_z on a resize event, so let it see this one.
        time.sleep(1.0)

    def client_rect(self):
        """The client area in screen coordinates: ``(left, top, width, height)``."""
        user32 = USER32
        cli = wintypes.RECT()
        origin = wintypes.POINT(0, 0)
        if not user32.GetClientRect(self.hwnd, ctypes.byref(cli)):
            raise _win32_error("GetClientRect")
        if not user32.ClientToScreen(self.hwnd, ctypes.byref(origin)):
            raise _win32_error("ClientToScreen")
        return (origin.x, origin.y, cli.right - cli.left, cli.bottom - cli.top)

    def _integrity_level(self, pid):
        """The process's mandatory integrity level, or None if it cannot be read.

        A medium-integrity process cannot read a high-integrity process's token, so None is
        itself evidence of a higher-integrity target: OpenProcess/OpenProcessToken fail with
        ERROR_ACCESS_DENIED across the UIPI boundary.
        """
        PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
        TOKEN_QUERY = 0x0008
        TokenIntegrityLevel = 25
        handle = KERNEL32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
        if not handle:
            return None
        try:
            token = wintypes.HANDLE()
            if not ADVAPI32.OpenProcessToken(handle, TOKEN_QUERY, ctypes.byref(token)):
                return None
            size = wintypes.DWORD()
            ADVAPI32.GetTokenInformation(token, TokenIntegrityLevel, None, 0, ctypes.byref(size))
            buffer = ctypes.create_string_buffer(size.value)
            if not ADVAPI32.GetTokenInformation(
                token, TokenIntegrityLevel, buffer, size.value, ctypes.byref(size)
            ):
                return None
            sid = ctypes.cast(buffer, ctypes.POINTER(ctypes.c_void_p))[0]
            count = ADVAPI32.GetSidSubAuthorityCount(sid)[0]
            return ADVAPI32.GetSidSubAuthority(sid, count - 1)[0]
        finally:
            KERNEL32.CloseHandle(handle)

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
        foreground = USER32.GetForegroundWindow()
        if not foreground or foreground == self.hwnd:
            return None
        pid = wintypes.DWORD()
        thread = USER32.GetWindowThreadProcessId(foreground, ctypes.byref(pid))
        our_thread = KERNEL32.GetCurrentThreadId()
        # The direct evidence: can we attach to its input queue at all?
        if thread and thread != our_thread:
            ctypes.set_last_error(0)
            if USER32.AttachThreadInput(our_thread, thread, True):
                USER32.AttachThreadInput(our_thread, thread, False)
                return None
            # ctypes' private last-error slot, which is populated only because USER32 is our own
            # use_last_error handle. ERROR_ACCESS_DENIED is the UIPI signature; anything else is
            # a transient refusal that retrying can still get past.
            if ctypes.get_last_error() != 5:
                return None
        ours = self._integrity_level(os.getpid())
        theirs = self._integrity_level(pid.value)
        title = ctypes.create_unicode_buffer(256)
        USER32.GetWindowTextW(foreground, title, 256)
        cls = ctypes.create_unicode_buffer(256)
        USER32.GetClassNameW(foreground, cls, 256)
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
        SW_RESTORE = 9
        # ShowWindow's BOOL return is the PREVIOUS visibility, not success, so it is not an
        # error indicator and is deliberately not checked.
        USER32.ShowWindow(self.hwnd, SW_RESTORE)
        target_thread = USER32.GetWindowThreadProcessId(self.hwnd, None)
        deadline = time.time() + FOCUS_TIMEOUT_SECONDS
        while time.time() < deadline:
            foreground = USER32.GetForegroundWindow()
            if foreground == self.hwnd:
                time.sleep(0.2)
                return
            our_thread = KERNEL32.GetCurrentThreadId()
            fg_thread = USER32.GetWindowThreadProcessId(foreground, None) if foreground else 0
            attached = []
            for thread in (fg_thread, target_thread):
                if (
                    thread
                    and thread != our_thread
                    and USER32.AttachThreadInput(our_thread, thread, True)
                ):
                    attached.append(thread)
            try:
                USER32.BringWindowToTop(self.hwnd)
                USER32.SetForegroundWindow(self.hwnd)
                USER32.SetActiveWindow(self.hwnd)
            finally:
                for thread in attached:
                    USER32.AttachThreadInput(our_thread, thread, False)
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
            f"{FOCUS_TIMEOUT_SECONDS}s; foreground is hwnd {USER32.GetForegroundWindow()}. "
            "Synthetic clicks go to whatever is focused, so this tier cannot run on a desktop "
            "whose foreground it cannot take (a screen locked or in use - ADR-0017)."
        )

    def assert_focused(self):
        """The window still owns the foreground. Checked immediately before every click.

        RE-TAKES the foreground rather than merely sampling it. A bare assert here is what made
        this tier's definition of done non-repeatable: measured over 35 consecutive runs of the
        DoD command on an otherwise idle machine, 34 passed and one failed with "the Oolite
        window lost the foreground before a click". ANYTHING that transiently owns the
        foreground between start()'s settle and this assert - a notification, an installer, or
        (caught red-handed on this machine) a sibling tool launching oolite.exe without taking
        tools/gui-lock - hard-failed the whole run, even though the condition was gone a fraction
        of a second later.

        focus() is the self-healing form select_row has always used, and it is not a softening:
        it retries for FOCUS_TIMEOUT_SECONDS and then hard-fails exactly as before, with the
        elevated-owner case still reported distinguishably. A foreground that is genuinely
        untakeable still fails the test; a foreground that was momentarily borrowed no longer
        does.
        """
        if USER32.GetForegroundWindow() == self.hwnd:
            return
        self.focus()
        foreground = USER32.GetForegroundWindow()
        assert foreground == self.hwnd, (
            f"the Oolite window lost the foreground before a click and could not retake it "
            f"within {FOCUS_TIMEOUT_SECONDS}s (foreground is hwnd {foreground}, game is "
            f"{self.hwnd}); the click would have gone to another window"
        )

    def assert_click_point_is_ours(self, x, y):
        """The window UNDER the click point is ours - which is not implied by owning the focus.

        THE THIRD FAILURE MODE. Foreground and Z-ORDER are different things, and a synthetic
        click made with mouse_event (which is what pyautogui uses - _pyautogui_win.py:432 _click
        -> _sendMouseEvent -> mouse_event; the SendInput branch is commented out at :483-492) is
        delivered BY POSITION to the topmost window at that point, exactly like a physical click.
        It does not go to the foreground window. So a window that sits ABOVE the game at the
        click point swallows the click while GetForegroundWindow() still answers with the game's
        hwnd and assert_focused() still passes - a correctly placed, correctly timed double-click
        on a correctly focused window that never reaches the game.

        The occluder observed on this desktop was a second oolite.exe. _pin_window parks every
        instance at exactly (0,0) at the same 960x720 client size, so any other instance covers
        this window's rows pixel for pixel, is the same class (SDL_app), and - being on the start
        screen itself - silently consumes the click. Measured directly: with one present,
        GetForegroundWindow() == our hwnd while WindowFromPoint(488,727) returned the OTHER
        instance's hwnd.

        WHERE THAT SECOND INSTANCE CAME FROM IS NOT ESTABLISHED. It was originally attributed to
        a leak from a failed start(), but that mechanism was DISPROVEN by measurement: when
        start() raises, the exception propagates through the ``yield window.start()`` expression
        inside the fixture generator and the ``finally:`` in the ``game`` fixture runs during the
        unwind, so the process was already being killed (instrumented on both trees; kill was
        called, and the launched pid was dead at session end). One launcher that DOES bypass the
        desktop lock has since been caught - tools/js_api_snapshot.py starts oolite.exe without
        taking tools/gui-lock - but this assert does not depend on knowing the source. It is what
        makes an occluded click point a named failure instead of a mystery miss, whatever put the
        window there.
        """
        under = USER32.WindowFromPoint(wintypes.POINT(x, y))
        GA_ROOT = 2
        root = USER32.GetAncestor(under, GA_ROOT) or under  # children belong to their frame
        if root == self.hwnd:
            return
        pid = wintypes.DWORD()
        USER32.GetWindowThreadProcessId(root, ctypes.byref(pid))
        cls = ctypes.create_unicode_buffer(256)
        USER32.GetClassNameW(root, cls, 256)
        title = ctypes.create_unicode_buffer(256)
        USER32.GetWindowTextW(root, title, 256)
        same_binary = cls.value == "SDL_app"
        pytest.fail(
            f"the click point {(x, y)} is OCCLUDED: the topmost window there is hwnd {root} "
            f"(class {cls.value!r}, title {title.value!r}, pid {pid.value}), not the game's hwnd "
            f"{self.hwnd}. The game still owns the FOREGROUND, but a synthetic click is "
            "delivered by position to whatever is on top at that point, so this click would "
            "have been swallowed and the game would simply keep running.\n"
            + (
                "That window is another Oolite instance (class SDL_app). Something else on this "
                "machine is running the game concurrently - check for a launcher that does not "
                "take tools/gui-lock. Kill any stray oolite.exe and re-run."
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

        # Re-takes the foreground if something transiently stole it, then asserts. A bare
        # sample here was one of the two structural causes of this tier's non-repeatable DoD.
        self.assert_focused()
        x, y = self.point_for_row(row)
        # Focus is not enough: the click goes to whatever is topmost AT THIS POINT. See
        # assert_click_point_is_ours - this is the third failure mode this bead was reworked for.
        self.assert_click_point_is_ours(x, y)
        pyautogui.doubleClick(x, y, interval=DOUBLE_CLICK_INTERVAL_SECONDS)

    def close_window(self):
        """Close the window the way the title-bar X does: post WM_CLOSE to its frame (G3).

        WHY THIS AND NOT A SYNTHETIC SDL EVENT. The behaviour under test is the user closing the
        window, and the honest boundary for a GUI-tier test is the one the window manager uses.
        A physical click on the X makes the frame send WM_SYSCOMMAND/SC_CLOSE, whose DefWindowProc
        handling posts WM_CLOSE to the window; SDL's Win32 backend translates that WM_CLOSE into
        SDL_EVENT_QUIT, which MyOpenGLView+Input.m:660-664 turns into
        ``[gameController exitAppWithContext:@"SDL_QUIT event received"]``. Posting WM_CLOSE
        enters that chain at the same place the window manager does, from OUTSIDE the process,
        through the game's real message queue. Calling SDL_PushEvent inside the game, or invoking
        exitAppWithContext directly, would assert that a function works rather than that closing
        the window works - and would still pass if the SDL_EVENT_QUIT case were deleted outright.

        Measured on this build before the test was written: PostMessageW(hwnd, WM_CLOSE) returned
        1 and oolite.exe exited with status 0 within ~2s.

        The pointer is NOT moved and nothing is clicked, so unlike select_row/confirm_row this
        does not depend on Z-order - a posted message goes to the window by HANDLE, not by
        position. assert_focused() is still called first: the window must be the live foreground
        one this test launched, not a leftover.
        """
        self.assert_focused()
        posted = USER32.PostMessageW(self.hwnd, WM_CLOSE, 0, 0)
        if not posted:
            raise _win32_error(f"PostMessageW(WM_CLOSE) to hwnd {self.hwnd}")
        return self.hwnd



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
    foreground = USER32.GetForegroundWindow()
    if not foreground:
        return None
    pid = wintypes.DWORD()
    thread = USER32.GetWindowThreadProcessId(foreground, ctypes.byref(pid))
    our_thread = KERNEL32.GetCurrentThreadId()
    if not thread or thread == our_thread:
        return None
    ctypes.set_last_error(0)
    if USER32.AttachThreadInput(our_thread, thread, True):
        USER32.AttachThreadInput(our_thread, thread, False)
        return None
    # ctypes' private last-error slot: populated only because USER32 is our own use_last_error
    # handle, so this is the real code rather than whatever a later Python call left behind.
    if ctypes.get_last_error() != 5:  # ERROR_ACCESS_DENIED is the UIPI signature
        return None
    title = ctypes.create_unicode_buffer(256)
    USER32.GetWindowTextW(foreground, title, 256)
    cls = ctypes.create_unicode_buffer(256)
    USER32.GetClassNameW(foreground, cls, 256)
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

    It POLLS rather than taking one instantaneous sample. This gate runs at session scope,
    before the desktop lock, and a UAC prompt or an installer owning the foreground for two
    seconds would otherwise fail an entire accept.sh run on a healthy tree for a condition that
    had already cleared by the time anyone looked. The budget is FOCUS_TIMEOUT_SECONDS, the same
    one focus() gives the foreground; only a blocker that PERSISTS for the whole of it fails.
    """
    deadline = time.time() + FOCUS_TIMEOUT_SECONDS
    blocker = describe_untakeable_foreground()
    while blocker and time.time() < deadline:
        time.sleep(0.5)
        blocker = describe_untakeable_foreground()
    if blocker:
        pytest.fail(
            f"{DESKTOP_UNUSABLE_MARKER}: this desktop cannot run the GUI tier right now.\n"
            f"  {blocker}\n"
            "Synthetic input goes to the focused window, and Windows forbids a medium-integrity "
            "process from taking the foreground away from an elevated one - AttachThreadInput "
            "cannot cross the UIPI boundary, so no retry can ever succeed. NOTHING IS WRONG WITH "
            "THE GAME OR WITH G1; close or minimise that window and re-run. (An elevated Task "
            f"Manager is the usual culprit.) This persisted for {FOCUS_TIMEOUT_SECONDS}s, so it "
            "is not a passing notification or installer."
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


# --- the GNUstep defaults file ------------------------------------------------------------------
#
# src/SDL/main.m:119 sets GNUSTEP_USERS_ROOT to the directory holding oolite.exe, so gnustep-base
# keeps this run's user defaults under <app_dir>/GNUstep/Defaults/. The domain file is named for
# the process (``oolite``), and GameController.m:905-906 -synchronize-s it on the way out of
# -exitAppWithContext: and then logs ".GNUstepDefaults synchronized." - which is precisely why
# "the defaults file still parses" is a meaningful post-exit check: a shutdown that died partway
# through that write leaves a truncated file behind.
DEFAULTS_RELATIVE_PATH = os.path.join("GNUstep", "Defaults", "oolite.plist")


def defaults_path_candidates(app_dir):
    """Every place this platform could have put the user defaults, best guess first."""
    candidates = [os.path.join(os.path.abspath(app_dir), DEFAULTS_RELATIVE_PATH)]
    # OO_GAME_DATA_TO_USER_FOLDER builds repoint HOMEPATH (main.m:120-124); and off Windows
    # main.m never sets GNUSTEP_USERS_ROOT at all, so the defaults land under $HOME.
    local = os.environ.get("LOCALAPPDATA")
    if local:
        candidates.append(os.path.join(local, "Oolite", "oolite.app", DEFAULTS_RELATIVE_PATH))
    home = os.path.expanduser("~")
    if home and home != "~":
        candidates.append(os.path.join(home, DEFAULTS_RELATIVE_PATH))
    seen = []
    for path in candidates:
        if path not in seen:
            seen.append(path)
    return seen


class DefaultsParseError(ValueError):
    """The defaults file exists but is not a well-formed property list."""


# Returned by defaults_write_mark for a path that did not exist at launch.
_ABSENT_AT_LAUNCH = None
# Distinguishes "marked, and it was absent" from "never marked at all".
_UNMARKED = object()


def defaults_write_mark(app_dir):
    """Snapshot every candidate defaults path's mtime AT LAUNCH. ``{path: (mtime_ns, size)}``.

    This is the half of the G9 defaults check that makes it falsifiable at all.
    ``app_dir`` is the PERSISTENT build tree (``_default_app_dir()`` ->
    ``upstream/oolite/build/meson_test/oolite.app``), so a defaults file left behind by a run
    last month satisfies "exists and parses" forever, and this run could write nothing at all
    without the check noticing. The story (docs/stories/G1-exit-via-mouse.md:52) asks for a
    defaults file WRITTEN and re-parseable; without a launch-time mark the "written" half is
    unfalsifiable - which is precisely the tautology class bug oo-5rsa exists to remove.

    A path absent at launch is recorded as ``None``: its later EXISTENCE is then proof of a
    write, which is a stronger witness than any timestamp.
    """
    mark = {}
    for path in defaults_path_candidates(app_dir):
        try:
            stat = os.stat(path)
        except OSError:
            mark[path] = _ABSENT_AT_LAUNCH
        else:
            mark[path] = (stat.st_mtime_ns, stat.st_size)
    return mark


def _openstep_tokens(text):
    """Tokenise an OpenStep (\"old-style\") property list.

    gnustep-base writes this dialect, not XML - see the file itself - so ``plistlib`` cannot
    read it and a check built on plistlib alone would fail on a perfectly healthy file.
    """
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c in " \t\r\n":
            i += 1
            continue
        if text.startswith("/*", i):
            end = text.find("*/", i + 2)
            if end < 0:
                raise DefaultsParseError(f"unterminated /* comment at offset {i}")
            i = end + 2
            continue
        if text.startswith("//", i):
            end = text.find("\n", i)
            i = n if end < 0 else end + 1
            continue
        if c == '"':
            out, i = [], i + 1
            while True:
                if i >= n:
                    raise DefaultsParseError("unterminated quoted string")
                d = text[i]
                if d == "\\":
                    if i + 1 >= n:
                        raise DefaultsParseError("truncated escape in quoted string")
                    out.append({"n": "\n", "t": "\t", "r": "\r"}.get(text[i + 1], text[i + 1]))
                    i += 2
                    continue
                if d == '"':
                    i += 1
                    break
                out.append(d)
                i += 1
            yield ("str", "".join(out))
            continue
        if c in "{}()=;,<>":
            yield ("punct", c)
            i += 1
            continue
        start = i
        while i < n and (text[i].isalnum() or text[i] in "_$+-./:@\\^~"):
            i += 1
        if i == start:
            raise DefaultsParseError(f"unexpected character {c!r} at offset {i}")
        yield ("str", text[start:i])


def parse_openstep_plist(text):
    """Parse an OpenStep plist into dicts/lists/strings, or raise DefaultsParseError.

    Deliberately strict: an unbalanced brace, a missing ``;`` or trailing garbage all raise.
    A lenient parser here would turn a half-written defaults file into a silent pass, which is
    the whole failure this check exists to catch.
    """
    tokens = list(_openstep_tokens(text))
    pos = 0

    def peek():
        return tokens[pos] if pos < len(tokens) else (None, None)

    def take(expected=None):
        nonlocal pos
        if pos >= len(tokens):
            raise DefaultsParseError(f"unexpected end of plist, wanted {expected or 'a token'}")
        tok = tokens[pos]
        pos += 1
        if expected is not None and tok != ("punct", expected):
            raise DefaultsParseError(f"wanted {expected!r}, found {tok[1]!r}")
        return tok

    def value():
        kind, text_ = take()
        if kind == "str":
            return text_
        if text_ == "{":
            out = {}
            while peek() != ("punct", "}"):
                ktype, key = take()
                if ktype != "str":
                    raise DefaultsParseError(f"dictionary key must be a string, found {key!r}")
                take("=")
                out[key] = value()
                take(";")
            take("}")
            return out
        if text_ == "(":
            out = []
            if peek() != ("punct", ")"):
                out.append(value())
                while peek() == ("punct", ","):
                    take(",")
                    if peek() == ("punct", ")"):
                        break
                    out.append(value())
            take(")")
            return out
        if text_ == "<":
            chunks = []
            while peek() != ("punct", ">"):
                ktype, chunk = take()
                if ktype != "str":
                    raise DefaultsParseError("malformed <...> data block")
                chunks.append(chunk)
            take(">")
            joined = "".join(chunks)
            try:
                return bytes.fromhex(joined)
            except ValueError as exc:
                raise DefaultsParseError(f"malformed hex in data block: {exc}") from exc
        raise DefaultsParseError(f"unexpected {text_!r} where a value was wanted")

    if not tokens:
        raise DefaultsParseError("the defaults file is empty")
    root = value()
    if pos != len(tokens):
        raise DefaultsParseError(f"trailing garbage after the root object: {tokens[pos][1]!r}")
    return root


def parse_defaults_file(path):
    """Read and parse a defaults file in whichever plist dialect it is written in.

    XML and binary first (``plistlib``), then the OpenStep dialect gnustep-base actually emits.
    Raises DefaultsParseError if no dialect can read it.
    """
    import plistlib

    with open(path, "rb") as handle:
        raw = handle.read()
    if not raw.strip():
        raise DefaultsParseError(f"{path} is empty")
    try:
        return plistlib.loads(raw)
    except Exception:
        pass
    try:
        return parse_openstep_plist(raw.decode("utf-8", errors="strict"))
    except UnicodeDecodeError as exc:
        raise DefaultsParseError(f"{path} is not valid UTF-8: {exc}") from exc


def assert_defaults_file_reparses(app_dir, launch_mark):
    """The defaults file was written BY THIS RUN and still parses. Returns ``(path, contents)``.

    GameController.m:905 synchronizes NSUserDefaults as the last thing before SDL_Quit, so this
    is a direct read of whether the orderly shutdown path completed its write.

    ``launch_mark`` comes from ``defaults_write_mark(app_dir)`` called AT LAUNCH and is
    mandatory. Without it this function could only assert that SOME defaults file exists and
    parses - and app_dir is the persistent build tree, so a plist written weeks ago satisfies
    that forever while this run writes nothing. "Exists" is not "was written"; only the mark
    can tell them apart.
    """
    assert launch_mark is not None, (
        "assert_defaults_file_reparses needs the launch-time mark from "
        "defaults_write_mark(app_dir); without it the check degrades to 'a defaults file "
        "exists somewhere', which a plist left by an earlier run satisfies forever (oo-5rsa)"
    )
    candidates = defaults_path_candidates(app_dir)
    found = [p for p in candidates if os.path.isfile(p)]
    assert found, (
        "no GNUstep defaults file after exit; GameController.m:905-906 synchronizes "
        "NSUserDefaults in -exitAppWithContext:, so an absent file means that write never "
        "happened. Looked in:\n  " + "\n  ".join(candidates)
    )

    # Which of the files that exist did THIS run actually write?
    fresh, stale = [], []
    for path in found:
        before = launch_mark.get(path, _UNMARKED)
        if before is _UNMARKED:
            # Not marked at launch, so nothing can be attributed to this run. Treated as stale
            # rather than quietly accepted: an unattributable file is exactly the evidence
            # this assertion is not allowed to rely on.
            stale.append(f"{path} (not marked at launch)")
            continue
        stat = os.stat(path)
        if before is _ABSENT_AT_LAUNCH:
            fresh.append(path)  # it did not exist at launch; its existence IS the write
        elif stat.st_mtime_ns > before[0]:
            fresh.append(path)
        else:
            stale.append(
                f"{path} (mtime unchanged since launch: {stat.st_mtime_ns} <= {before[0]}, "
                f"size {stat.st_size} vs {before[1]})"
            )
    assert fresh, (
        "the defaults file exists but THIS RUN did not write it - every candidate is exactly "
        "as it was at launch, so the -synchronize in GameController.m:905-906 never landed and "
        "what is on disk is a leftover from an earlier run. app_dir is the persistent build "
        "tree, so 'a defaults file exists and parses' is true forever and proves nothing "
        "(oo-5rsa). Unwritten:\n  " + "\n  ".join(stale)
    )

    path = fresh[0]
    try:
        contents = parse_defaults_file(path)
    except DefaultsParseError as exc:
        raise AssertionError(
            f"the defaults file {path} no longer parses after exit: {exc}. A truncated or "
            "corrupt defaults file is a shutdown that died partway through its final write."
        ) from exc
    assert isinstance(contents, dict), (
        f"the defaults file {path} parsed to a {type(contents).__name__}, not a dictionary"
    )
    assert contents, f"the defaults file {path} parsed to an empty dictionary"
    return path, contents


# --- surviving processes -------------------------------------------------------------------------


def _windows_process_table():
    """``[(pid, parent_pid, exe_name_lowercased), ...]`` via CreateToolhelp32Snapshot.

    Every call goes through KERNEL32 with the argtypes/restype declared in WIN32_SIGNATURES
    (oo-x2uy). The snapshot HANDLE in particular must be declared: undeclared, ctypes decodes
    it through a 32-bit signed int, and the truncated handle makes Process32First fail - which
    this reader would report as an empty process table, i.e. "nothing survived".
    """
    TH32CS_SNAPPROCESS = 0x00000002
    INVALID_HANDLE_VALUE = ctypes.c_void_p(-1).value

    snapshot = KERNEL32.CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
    if not snapshot or snapshot == INVALID_HANDLE_VALUE:
        raise _win32_error("CreateToolhelp32Snapshot")
    entry = PROCESSENTRY32()
    entry.dwSize = ctypes.sizeof(PROCESSENTRY32)
    rows = []
    try:
        ok = KERNEL32.Process32First(snapshot, ctypes.byref(entry))
        if not ok:
            # ERROR_NO_MORE_FILES on the very first call means the snapshot handle was bad.
            # An empty table here would be read as "no survivors" by every caller, so it is a
            # hard error rather than an empty list.
            raise _win32_error("Process32First")
        while ok:
            rows.append(
                (
                    int(entry.th32ProcessID),
                    int(entry.th32ParentProcessID),
                    entry.szExeFile.decode("mbcs", errors="replace").lower(),
                )
            )
            ok = KERNEL32.Process32Next(snapshot, ctypes.byref(entry))
    finally:
        KERNEL32.CloseHandle(snapshot)
    return rows


def _posix_process_table():
    """``[(pid, parent_pid, comm_lowercased), ...]`` from /proc.

    WARNING - this table cannot support the descendant walk that surviving_game_processes does
    on Windows, and the walk knows it (see that function). Linux reparents an orphan to init or
    to the nearest subreaper the moment its parent dies, so once the root process exits, a
    surviving grandchild's ppid is 1 and a tree walk rooted at the old pid finds nothing: a
    silent pass, exactly the defect class oo-5rsa exists to remove. Windows does not do this -
    th32ParentProcessID retains the (possibly dead) creator's pid - which is why the walk is
    sound there and falls back to an unscoped image-name sweep here.
    """
    rows = []
    for name in os.listdir("/proc"):
        if not name.isdigit():
            continue
        try:
            with open(f"/proc/{name}/stat", "r", encoding="utf-8", errors="replace") as fh:
                stat = fh.read()
            comm = stat[stat.index("(") + 1 : stat.rindex(")")]
            rest = stat[stat.rindex(")") + 1 :].split()
            rows.append((int(name), int(rest[1]), comm.lower()))
        except (OSError, ValueError, IndexError):
            continue
    return rows


def _process_table():
    return _windows_process_table() if IS_WINDOWS else _posix_process_table()


GAME_PROCESS_NAMES = ("oolite.exe", "oolite")


def surviving_game_processes(root_pid):
    """Live Oolite processes that are ``root_pid`` or descended from it.

    Scoped to OUR process tree on purpose. A bare "is any oolite.exe running?" would be a
    false positive against a concurrent sibling GUI run on the same desktop, and this tier is
    not permitted to make another run's process look like its own leak.
    """
    rows = _process_table()
    children = {}
    names = {}
    for pid, parent, name in rows:
        names[pid] = name
        if pid != parent:
            children.setdefault(parent, []).append(pid)
    ours, stack = set(), [root_pid]
    while stack:
        pid = stack.pop()
        if pid in ours:
            continue
        ours.add(pid)
        stack.extend(children.get(pid, ()))
    return sorted(
        (pid, names[pid])
        for pid in ours
        if pid in names and names[pid] in GAME_PROCESS_NAMES
    )


def assert_no_surviving_game_processes(root_pid, timeout=10.0):
    """FAIL if any oolite.exe in the launched process tree is still alive.

    Note what this is NOT: re-reading ``Popen.returncode`` after ``wait()`` has already reaped
    it. That can only ever return the value wait() just stored, so it is true by construction
    and checks nothing. The operating system's process table is the only witness that can say
    "no" here.
    """
    deadline = time.time() + timeout
    survivors = surviving_game_processes(root_pid)
    while survivors and time.time() < deadline:
        time.sleep(0.25)
        survivors = surviving_game_processes(root_pid)
    assert not survivors, (
        "orphaned game process(es) survived the exit: "
        + ", ".join(f"{name} (pid {pid})" for pid, name in survivors)
        + f" - still alive {timeout}s after the process tree rooted at pid {root_pid} was "
        "supposed to be gone"
    )


# --- the G9 assertion itself ---------------------------------------------------------------------


def assert_clean_exit(game_or_output_dir, app_dir=None, defaults_launch_mark=None):
    """No core dump, no ERROR in Latest.log, and a defaults file THIS RUN wrote and can reparse.

    docs/phases/0-gui-tier.md G9. A shutdown that leaves any of these behind has not worked,
    however zero its exit status.

    Call it with the fixture: ``assert_clean_exit(game)``. Everything it needs - the output
    directory, the app directory, and the launch-time defaults mark - lives on the GameWindow,
    so there is one obvious spelling and no way to call it with a subset of the evidence. The
    explicit three-argument form stays for tests that synthesise directories.

    A one-argument ``assert_clean_exit(output_dir)`` is NOT valid: without ``app_dir`` there is
    no defaults check at all, and without the launch mark the defaults check cannot fail. Both
    raise here with instructions rather than silently checking less (oo-5rsa).

    All checks are unconditional. An ABSENT Latest.log is a failure, not a pass: by the time
    any test reaches here, ``_await_startup_complete`` has already read ``startup.complete``
    out of that very file in this very run, so the file not being there means something
    deleted or moved it and the log check would otherwise evaporate into a silent pass.
    """
    output_dir, app_dir, defaults_launch_mark = _clean_exit_arguments(
        game_or_output_dir, app_dir, defaults_launch_mark
    )

    dumps = [
        f
        for f in os.listdir(output_dir)
        if f.endswith((".dmp", ".core")) or f.startswith("core.")
    ]
    assert not dumps, f"crash dump(s) left behind: {dumps}"

    log = os.path.join(output_dir, "Latest.log")
    assert os.path.isfile(log), (
        f"no Latest.log at {log} after exit. _await_startup_complete read 'startup.complete' "
        "out of this file earlier in this same run, so it existed; skipping the log check "
        "because it has since vanished would report a pass for a check that never ran."
    )
    with open(log, "r", encoding="utf-8", errors="replace") as handle:
        bad = [
            line.strip()
            for line in handle
            if "ERROR" in line or "EXCEPTION" in line.upper()
        ]
    assert not bad, "errors in Latest.log:\n" + "\n".join(bad[:10])

    return assert_defaults_file_reparses(app_dir, defaults_launch_mark)


def _clean_exit_arguments(game_or_output_dir, app_dir, defaults_launch_mark):
    """Resolve assert_clean_exit's arguments, refusing any call that would check less.

    Separated out so assert_clean_exit's own body stays free of the ``if`` statements
    test_assert_clean_exit_runs_every_check_unconditionally forbids: not one of the checks
    below is allowed to be conditional, and this function guards the INPUTS, not the checks.
    """
    if isinstance(game_or_output_dir, GameWindow):
        game = game_or_output_dir
        assert app_dir is None and defaults_launch_mark is None, (
            "pass either assert_clean_exit(game) or the explicit "
            "assert_clean_exit(output_dir, app_dir, mark), not a mixture"
        )
        return game.output_dir, game.app_dir, game.defaults_launch_mark

    assert app_dir is not None, (
        "assert_clean_exit needs the app directory as well as the output directory: the G9 "
        "defaults check reads <app_dir>/GNUstep/Defaults/oolite.plist, and a one-argument "
        "call would skip it entirely. Call assert_clean_exit(game) (oo-5rsa)."
    )
    assert defaults_launch_mark is not None, (
        "assert_clean_exit needs the launch-time defaults mark (GameWindow.start() records it "
        "as game.defaults_launch_mark). Without it the defaults check can only say 'a file "
        "exists', which a plist from an earlier run satisfies forever. Call "
        "assert_clean_exit(game) (oo-5rsa)."
    )
    return game_or_output_dir, app_dir, defaults_launch_mark
