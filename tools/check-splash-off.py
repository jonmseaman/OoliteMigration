#!/usr/bin/env python3
"""Behavioural check: a GUI-tier launch must run with the splash screen OFF.

The spelling of the launch flag is not the defect - the splash running is. A misspelled flag
is silently ignored (MyOpenGLView.m:363 matches ``-nosplash``/``--nosplash`` with an exact
``isEqual:``), so grepping conftest.py proves only that today's spelling is today's spelling.

The runtime observable is the ORDER of lines the game already logs:

* splash OFF - MyOpenGLView.m:431 ``if (!showSplashScreen)`` calls ``initialiseGLWithSize:``
  at :434 during ``-init``, BEFORE any resource loading, so "Requested a new surface of
  W x H, windowed" appears EARLY, before ``shipData.load.begin``;
* splash ON  - that block is skipped and the call is deferred to :507 in ``endSplashScreen``,
  which GameController.m:313 fires at the end of startup, after Universe init and
  loadPlayerIfRequired - so the surface line lands AFTER the loading phase.

Note "before startup.complete" is NOT enough: with the splash on the surface line still
precedes startup.complete by a couple of lines. "Before resource loading" is the real split.

logcontrol.plist:131 enables ``display.initGL`` by default, so the lines are in every log.

This launches the real binary once and asserts the ordering, reusing the same assertion the
GUI tier itself applies on every launch (tests/gui/conftest.py::assert_splash_screen_is_off).

Exit status: 0 pass, 1 fail. When no built binary exists anywhere (the detached, build-less
checkout an acceptance merge runs in) it prints a loud SKIPPED banner and exits 0 - it never
passes quietly.
"""

import os
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, ".."))
READY_TIMEOUT = int(os.environ.get("OO_GUI_READY_TIMEOUT", "180"))
SOFTWARE_GL_DLLS = ("opengl32.dll", "libgallium_wgl.dll")
PARKED_SUFFIX = ".splash-check-parked"


def _normalise(path):
    """MSYS ``/c/Users/...`` -> ``C:/Users/...``; anything else is returned unchanged."""
    if len(path) > 2 and path[0] == "/" and path[2] in ("/", "") and path[1].isalpha():
        return path[1].upper() + ":" + path[2:]
    return path


def _candidate_app_dirs():
    """Every place a built ``oolite.app`` might be, most specific first.

    A merge-acceptance run happens in a detached, freshly exported checkout where ``build/``
    is gitignored and therefore absent, so the build is resolved from the MAIN checkout via
    the shared git common dir (``.git`` of the primary worktree).
    """
    seen = []

    def add(path):
        if path:
            path = os.path.normpath(_normalise(path))
            if path not in seen:
                seen.append(path)

    add(os.environ.get("OO_APP_DIR"))
    add(os.path.join(REPO, "upstream", "oolite", "build", "meson_test", "oolite.app"))
    try:
        common = subprocess.run(
            ["git", "rev-parse", "--git-common-dir"],
            cwd=REPO,
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        common = ""
    if common:
        common = _normalise(common)
        if not os.path.isabs(common):
            common = os.path.join(REPO, common)
        main_root = os.path.dirname(os.path.abspath(common))
        add(os.path.join(main_root, "upstream", "oolite", "build", "meson_test", "oolite.app"))
    return seen


def _find_binary():
    name = "oolite.exe" if os.name == "nt" else "oolite"
    for app_dir in _candidate_app_dirs():
        path = os.path.join(app_dir, name)
        if os.path.isfile(path):
            return app_dir, path
    return None, None


def _load_assertion():
    gui = os.path.join(REPO, "upstream", "oolite", "tests", "gui")
    sys.path.insert(0, gui)
    import conftest  # noqa: E402  - located at runtime, on purpose

    return conftest


LAUNCH_ARGS = None  # filled from conftest so the check runs exactly what the tier runs


def _self_test():
    """Check the assertion itself against both recorded log orderings. Needs no binary.

    These two extracts are the real thing, trimmed: captured from this build on 2026-09-16,
    one launch with -nosplash and one with the silently-ignored --no-splash. They keep the
    acceptance honest in a checkout with no build/ - the assertion must accept the first and
    reject the second.
    """
    conftest = _load_assertion()
    splash_off = "\n".join(
        [
            "[process.args]: Startup command: oolite.exe -nosplash -windowed",
            "[display.initGL]: Trying 8-bpcc, 24-bit depth buffer",
            "[display.initGL]: Requested a new surface of 960 x 720, windowed.",
            "[display.initGL]: Created a new surface of 960 x 720, windowed.",
            "[searchPaths.dumpAll]: Resource paths:",
            "[shipData.load.begin]: Loading ship data.",
            "[startup.complete]: ========== Loading complete in 2.53 seconds. ==========",
        ]
    )
    splash_on = "\n".join(
        [
            "[process.args]: Startup command: oolite.exe --no-splash -windowed",
            "[display.initGL]: Trying 8-bpcc, 24-bit depth buffer",
            "[searchPaths.dumpAll]: Resource paths:",
            "[shipData.load.begin]: Loading ship data.",
            "[display.initGL]: Requested a new surface of 960 x 720, windowed.",
            "[display.initGL]: Created a new surface of 960 x 720, windowed.",
            "[startup.complete]: ========== Loading complete in 2.63 seconds. ==========",
        ]
    )
    try:
        conftest.assert_splash_screen_is_off(splash_off, "<recorded splash-off log>")
    except AssertionError as exc:
        print(f"SELF-TEST FAIL: rejected a splash-OFF log: {exc}")
        return 1
    try:
        conftest.assert_splash_screen_is_off(splash_on, "<recorded splash-on log>")
    except AssertionError:
        print("SELF-TEST PASS: accepts the splash-off ordering, rejects the splash-on ordering.")
        return 0
    print("SELF-TEST FAIL: accepted a splash-ON log; the check does not gate the defect.")
    return 1


def main():
    global LAUNCH_ARGS
    if "--self-test" in sys.argv[1:]:
        return _self_test()
    app_dir, binary = _find_binary()
    if binary is None:
        print("=" * 78)
        print("SKIPPED: no built oolite binary in any of:")
        for candidate in _candidate_app_dirs():
            print(f"  - {candidate}")
        print("The splash-ordering check needs a real launch; build with")
        print("  tools/build-windows.sh test")
        print("or point OO_APP_DIR at an existing oolite.app, then re-run this check.")
        print("=" * 78)
        return 0

    conftest = _load_assertion()
    assert_splash_screen_is_off = conftest.assert_splash_screen_is_off
    splash_evidence = conftest.splash_evidence
    LAUNCH_ARGS = list(conftest.LAUNCH_ARGS)

    lock = os.path.join(REPO, "tools", "gui-lock")
    held = os.path.isfile(lock) and subprocess.run(
        ["bash", lock, "acquire", "--timeout", os.environ.get("OO_GUI_LOCK_TIMEOUT", "900")],
        capture_output=True,
        text=True,
    ).returncode == 0

    parked = []
    proc = None
    try:
        # Mesa's software GL is fatal for a real on-screen window (see conftest.py), so it is
        # moved aside for the duration exactly as the GUI tier does, and put back below.
        for dll in SOFTWARE_GL_DLLS:
            live = os.path.join(app_dir, dll)
            if os.path.isfile(live):
                os.replace(live, live + PARKED_SUFFIX)
                parked.append(live)

        out = tempfile.mkdtemp(prefix="oolite-splash-check-")
        env = os.environ.copy()
        env["SDL_AUDIODRIVER"] = "dummy"
        env["ALSOFT_DRIVERS"] = "null"
        # The game does not create this directory; without it, it logs to stdout instead.
        os.makedirs(out, exist_ok=True)
        env["OO_SNAPSHOTSDIR"] = out
        env["OO_LOGSDIR"] = out

        print(f"launching {binary} {' '.join(LAUNCH_ARGS)} (logs in {out})")
        proc = subprocess.Popen(
            [binary] + LAUNCH_ARGS,
            cwd=app_dir,
            env=env,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

        log = os.path.join(out, "Latest.log")
        deadline = time.time() + READY_TIMEOUT
        text = ""
        while time.time() < deadline:
            if proc.poll() is not None:
                print(f"FAIL: Oolite exited with {proc.returncode} during startup; see {log}")
                return 1
            if os.path.isfile(log):
                with open(log, "r", encoding="utf-8", errors="replace") as handle:
                    text = handle.read()
                if "startup.complete" in text:
                    break
            time.sleep(0.5)
        else:
            surface, loading, startup = splash_evidence(text)
            print(
                f"FAIL: Oolite did not finish loading within {READY_TIMEOUT}s "
                f"(surface line {surface}, loading line {loading}, startup line {startup}); "
                f"see {log}"
            )
            return 1

        try:
            surface, loading, startup = assert_splash_screen_is_off(text, log)
        except AssertionError as exc:
            print(f"FAIL: {exc}")
            return 1
        print(
            f"PASS: GL surface created at log line {surface}, resource loading began at line "
            f"{loading}, startup.complete at line {startup} - the surface predates loading, "
            "so the splash screen did not run."
        )
        return 0
    finally:
        if proc is not None and proc.poll() is None:
            proc.kill()
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                pass
        while parked:
            live = parked.pop()
            if os.path.isfile(live + PARKED_SUFFIX):
                os.replace(live + PARKED_SUFFIX, live)
        if held:
            subprocess.run(["bash", lock, "release"], capture_output=True)


if __name__ == "__main__":
    sys.exit(main())
