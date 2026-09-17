"""The Python side of ``tools/gui-lock`` for every launcher that is NOT the pytest GUI tier.

Why this module exists (bug oo-ccy9). ``tools/gui-lock`` is the interactive desktop's mutex, and
until this landed only ONE caller took it: the GUI tier's ``desktop_lock`` fixture
(upstream/oolite/tests/gui/conftest.py). Every other tool that launches the game launched it
straight onto the same desktop. On Windows that is not a theoretical overlap:
``SDL_VIDEODRIVER=offscreen`` is deliberately left unset here (MSYS2's Mesa ships no EGL, so the
offscreen driver cannot create a context and the game dies during init - see
tests/component/console.py::_env), so a "headless" console-driven launch still opens a REAL window
on the real desktop and can take the foreground. A JS-API snapshot run therefore stole the
foreground out from under a running G1 click; measured once in 35 G1 runs on a clean tree.

So the rule is: **any tool that launches the game on the interactive desktop takes this lock** -
not just the pytest tier. The two deliberate exemptions are listed in tools/check-desktop-lock.sh,
which also enforces this rule mechanically.

This module is a thin wrapper, not a second implementation. tools/gui-lock stays the single source
of truth for the lock path, the stale window and the reap gate; we only shell out to it. The one
thing added here is the OWNER IDENTITY: the script's fallback identity is ``<host>:$PPID``, and a
bash spawned by a *native* Windows python reports ``PPID=1``, so every python launcher would claim
the identity ``<host>:1`` and could release another run's lock. Each caller passes a distinct tag
and we append our own pid, exactly as the GUI tier's ``_lock_owner`` does.
"""

import contextlib
import os
import platform
import shutil
import subprocess
import sys
import threading


class DesktopLockError(RuntimeError):
    """The desktop lock could not be taken, so the game must not be launched."""


def gui_lock_script(start=None):
    """Absolute path to ``tools/gui-lock``, or None when there is no checkout around us.

    Found by walking up from ``start`` rather than by a fixed number of ``..``, so the same
    helper works from tools/ and from a subtree several directories down.
    """
    here = os.path.abspath(start or __file__)
    if os.path.isfile(here):
        here = os.path.dirname(here)
    while True:
        candidate = os.path.join(here, "tools", "gui-lock")
        if os.path.isfile(candidate):
            return candidate
        parent = os.path.dirname(here)
        if parent == here:
            return None
        here = parent


def owner_identity(tag):
    """This run's owner identity: stable across our acquire and our release, unique to us.

    ``OO_GUI_LOCK_OWNER`` wins when the caller set it (an acquire and a release running as two
    separate CI steps need to agree on an identity neither process can derive).
    """
    explicit = os.environ.get("OO_GUI_LOCK_OWNER")
    if explicit:
        return explicit
    host = os.environ.get("HOSTNAME") or platform.node()
    return f"{host}:{tag}{os.getpid()}"


def heartbeat_interval(stale=None):
    """How often to refresh the lock, from the stale window in force.

    A third of the window, so two consecutive refreshes may be lost (a slow machine, a paused
    process, a `bash` that took a second to start) before the lock is anywhere near stale - and
    floored at 5s so a deliberately tiny OO_GUI_LOCK_STALE in a test does not spin.
    """
    if stale is None:
        stale = os.environ.get("OO_GUI_LOCK_STALE", "1800")
    try:
        stale = int(float(stale))
    except (TypeError, ValueError):
        stale = 1800
    return max(5, stale // 3)


@contextlib.contextmanager
def desktop_lock(tag, timeout=None, start=None, stream=None):
    """Hold the desktop mutex for the duration of the ``with`` body.

    ``tag`` names the tool in the owner identity, so ``tools/gui-lock status`` says who is on the
    desktop and so the ownership-checked release can tell two tools apart.

    Failure to acquire raises DesktopLockError: the caller must NOT launch the game anyway. That
    is the bug this module exists for - tools/check-splash-off.py used to acquire "best effort"
    and launch regardless, which is the same collision with extra steps.

    THE HOLD IS HEARTBEATED (bug oo-ccy9, review 1). tools/gui-lock reclaims a lock older than
    OO_GUI_LOCK_STALE (default 1800s) so a holder that died cannot wedge the desktop for ever.
    But the JS-API snapshot holds the desktop for a WHOLE enumeration - up to
    MAX_SESSION_RESTARTS=80 sessions at OO_READY_TIMEOUT (default 240s) each - which can exceed
    half an hour on a contended machine. Without a heartbeat the lock would go stale UNDER A LIVE
    HOLDER: another launcher would legitimately reclaim it and put a SECOND GAME on the desktop
    while this one is still being driven (the exact bug), and this run's own release would then
    hit the ownership refusal below and merely warn.

    So a daemon thread calls ``gui-lock refresh`` every ``heartbeat_interval()`` seconds while the
    body runs. This does NOT defeat the stale mechanism, which is the thing that must not happen:
    the refresh is a PUSH from the live holder and is ownership-checked, so a holder that crashes,
    is killed, or hangs at the OS level stops refreshing, the mtime ages from its last refresh,
    and the lock goes stale on schedule. A dead process cannot heartbeat. The thread is a daemon
    and is joined in the ``finally``, so it can never outlive the interpreter or the hold.

    AND THE HEARTBEAT ITSELF IS WATCHED (review 2). A review measured this thread dying silently:
    only ``subprocess.run`` was inside the try, so a ``print`` to a closed or redirected stream -
    and both js_api_snapshot and launch_snapshot run under captured stdio - raised out of the
    thread. The interpreter printed "Exception in thread desktop-lock-heartbeat" and NOTHING ELSE
    NOTICED: the body kept running, un-refreshed, until the lock went stale under a live holder,
    which is the precise bug this fix exists for, silently restored. So now the whole loop body is
    guarded, logging can never raise out of it, a watchdog thread polls ``beat.is_alive()`` once a
    second and reports a death WHILE THE BODY RUNS, and the ``finally`` raises DesktopLockError if
    the heartbeat died - a result computed while the desktop mutex was not being held is not a
    result to return quietly.

    Release runs in a ``finally`` and is therefore reached on a crash, an exception or a
    ``KeyboardInterrupt``; it is the script's ownership-checked release, never an ``rm -rf``, so a
    teardown that runs after our lock was already stale-reclaimed by somebody else refuses rather
    than dropping a live holder's lock.

    With no bash or no checkout (the subtree pushed to the fork, where tools/ does not exist) there
    is no lock to take and no fleet to collide with, so the body runs with a loud warning rather
    than failing: this must not make the upstream tree unrunnable on its own.
    """
    out = stream or sys.stderr

    def _say(msg):
        """Never let logging kill the heartbeat: a dead heartbeat is worse than a lost line.

        Falls back to the real stderr when the caller's stream is gone, because the one thing
        that must reach a human is "the desktop mutex stopped being refreshed".
        """
        for stream in (out, sys.__stderr__):
            try:
                if stream is None:
                    continue
                print(msg, file=stream, flush=True)
                return
            except Exception:  # noqa: BLE001 - try the next stream
                continue

    script = gui_lock_script(start)
    bash = shutil.which("bash")
    if not (script and bash):
        _say(
            f"[!] desktop lock: no tools/gui-lock reachable from {start or __file__} "
            "(or no bash); launching WITHOUT the desktop mutex"
        )
        yield None
        return

    me = owner_identity(tag)
    env = dict(os.environ, OO_GUI_LOCK_OWNER=me)
    if timeout is None:
        timeout = os.environ.get("OO_GUI_LOCK_TIMEOUT", "900")
    held = subprocess.run(
        [bash, script, "acquire", "--timeout", str(timeout)],
        capture_output=True,
        text=True,
        env=env,
    )
    if held.returncode != 0:
        raise DesktopLockError(
            "could not take the GUI desktop lock as "
            f"{me}: {held.stderr.strip() or held.stdout.strip()}"
        )
    path = held.stdout.strip()
    _say(f"[*] desktop lock: held by {me} at {path}")

    # The heartbeat. Daemon so a hard exit can never be blocked by it; stopped and joined in the
    # finally so it can never outlive the hold and keep a released (or reclaimed) lock alive.
    #
    # THE WHOLE LOOP BODY IS INSIDE THE except (bug oo-ccy9, review 2). Attempt 2 guarded only the
    # subprocess.run; the refused-branch print was outside it. Writing to ``out`` CAN raise - a
    # closed or redirected stream, a broken pipe, and js_api_snapshot and launch_snapshot both run
    # under captured stdio - and a raise there killed the daemon thread outright. MEASURED: the
    # interpreter printed "Exception in thread desktop-lock-heartbeat", the thread list dropped to
    # ['MainThread'], and the body kept running with the lock NO LONGER BEING REFRESHED until it
    # went stale under a live holder: the exact bug this module exists to fix, silently restored.
    # So: nothing in the loop may escape, and a heartbeat that stops beating must be NOTICED -
    # see the beat.is_alive() check in the finally.
    stop = threading.Event()
    interval = heartbeat_interval()

    def _beat():
        # A TEST SEAM, and the only way to prove the liveness check below is not vacuous: no
        # amount of breaking the loop from outside can kill this thread any more (that is the
        # point of the two layers), so the selftest needs a supported way to simulate a heartbeat
        # that stopped beating. Only ever set by tools/desktop-lock-selftest.
        if os.environ.get("OO_GUI_LOCK_HEARTBEAT_KILL") == "1":
            return
        # Two layers on purpose. The inner try makes the normal failure modes (a refresh that
        # errors, a stream that raises) non-fatal; the outer loop SELF-HEALS anything unforeseen,
        # so an exception no one predicted costs one refresh instead of the whole heartbeat. The
        # thread only ends when `stop` is set - and if it ever ends anyway, the finally notices.
        while not stop.is_set():
            try:
                while not stop.wait(interval):
                    try:
                        r = subprocess.run(
                            [bash, script, "refresh"],
                            capture_output=True, text=True, env=env,
                        )
                        if r.returncode != 0:
                            # We no longer own the lock: somebody reclaimed it, or it was
                            # released. Say so loudly - a second process may now be on the desktop
                            # - but keep the body running; tearing down mid-enumeration from a
                            # daemon thread would be worse.
                            _say(
                                "[!] desktop lock: heartbeat refused, we may no longer hold the "
                                f"desktop: {r.stderr.strip() or r.stdout.strip()}"
                            )
                    except Exception as exc:  # noqa: BLE001 - never kill the heartbeat
                        _say(f"[!] desktop lock: heartbeat error: {exc}")
            except BaseException as exc:  # noqa: BLE001 - including anything _say could not catch
                _say(f"[!] desktop lock: heartbeat restarting after: {exc!r}")

    beat = threading.Thread(target=_beat, name="desktop-lock-heartbeat", daemon=True)
    beat.start()

    # LIVENESS WATCHDOG (bug oo-ccy9, review 2). The finding was not just "the thread can die" but
    # "the thread can die and NOTHING NOTICES" - no main-thread check existed, so the hold ran on
    # un-refreshed until the lock went stale under a live holder. This polls once a second while
    # the body runs, so the death is reported WHILE IT MATTERS and not only at teardown.
    dead = threading.Event()

    def _watch():
        while not stop.wait(1.0):
            if not beat.is_alive():
                if not dead.is_set():
                    dead.set()
                    _say(
                        "[!] desktop lock: HEARTBEAT DIED while the body is still running; this "
                        "hold is NOT being refreshed and the lock may be stale-reclaimed out from "
                        "under us - another launcher may take the desktop alongside us"
                    )
                return

    watch = threading.Thread(target=_watch, name="desktop-lock-watchdog", daemon=True)
    watch.start()
    try:
        yield path
    finally:
        # Belt to the watchdog's braces: catch a death it had no time to poll for.
        if not stop.is_set() and not beat.is_alive():
            dead.set()
        died = dead.is_set()
        stop.set()
        beat.join(timeout=30)
        watch.join(timeout=5)
        dropped = subprocess.run(
            [bash, script, "release"], capture_output=True, text=True, env=env
        )
        if dropped.returncode != 0:
            _say(f"[!] desktop lock: release refused: {dropped.stderr.strip()}")
        else:
            _say(f"[*] desktop lock: released by {me}")
        if died and sys.exc_info()[0] is None:
            # FAIL LOUDLY, not just verbosely. The body's result was produced while the desktop
            # mutex was un-refreshed, so it may have shared the desktop with another launcher and
            # cannot be trusted. Only raised when the body itself did not raise, so a real failure
            # is never masked by this one.
            raise DesktopLockError(
                f"the desktop-lock heartbeat for {me} died while the body was still running; "
                "the hold went un-refreshed and may have been stale-reclaimed"
            )


def import_from(start):
    """Import this module from a tree that does not have tools/ on sys.path.

    Used by the subtree's own launchers, which live under upstream/oolite/tests/ and must keep
    working when that subtree is pushed to the fork on its own. Returns None when there is no
    repository around the caller, which the caller treats as "no lock to take".
    """
    script = gui_lock_script(start)
    if not script:
        return None
    tools = os.path.dirname(script)
    if tools not in sys.path:
        sys.path.insert(0, tools)
    import desktop_lock  # noqa: F401  - this module, reached by path

    return desktop_lock