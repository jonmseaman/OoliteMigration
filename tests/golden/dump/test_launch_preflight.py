"""Pin the launch preflight that unblocked bead oo-gla's three-run determinism gate.

THE INCIDENT THIS GUARDS. Acceptance line 8 launches run_dump.py three times. It failed with
`console.ConsoleError: Oolite exited with 3221225781 before connecting to the console`, each
launch taking 116.2s and producing a zero-byte dump and NO Latest.log at all. 3221225781 is
0xC0000135 = STATUS_DLL_NOT_FOUND: the Windows image loader killed the process before its entry
point, which is why no log existed to diagnose it from.

It looked intermittent "in time" - the same script from the same paths returned rc=0 in 4s during
other windows with no change to the repo, the app dir or the gate. It is not intermittent. The
variable is the PATH of the SHELL that invokes the script:

    with    /ucrt64/bin on PATH -> rc=0, a real dump, ~4s warm
    without /ucrt64/bin on PATH -> rc=1, 3221225781, 0 bytes, 116s of doomed retries

The dependency is TRANSITIVE, which is why direct-import checks cleared the binary and made the
failure look mysterious: all 32 of oolite.exe's own imports resolve from the app dir plus
System32. It is Mesa's libgallium_wgl.dll - LoadLibrary()d at initGL time by the staged
opengl32.dll, so it appears in no static import table of oolite.exe - that needs libLLVM-22.dll,
libSPIRV-Tools.dll and libsystre-0.dll, and those three exist ONLY in the UCRT64 runtime dir.

These tests are offline: they exercise the dependency walker and the preflight's decision logic
against the real build directory without launching a game.
"""

import os
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(REPO_ROOT, "upstream", "oolite", "tests", "component"))

import state_dump  # noqa: E402

APP_DIR = os.environ.get(
    "OO_APP_DIR",
    os.path.join(REPO_ROOT, "upstream", "oolite", "build", "meson_test", "oolite.app"),
)

needs_build = pytest.mark.skipif(
    not os.path.isdir(APP_DIR), reason="no Oolite build at %s" % APP_DIR
)

# The three transitive dependencies the incident was actually about.
GALLIUM_DEPS = {"libllvm-22.dll", "libspirv-tools.dll", "libsystre-0.dll"}


def _runtime_dir():
    for cand in state_dump._candidate_runtime_dirs():
        names = {n.lower() for n in os.listdir(cand)}
        if GALLIUM_DEPS <= names:
            return cand
    return None


@needs_build
def test_the_exe_alone_looks_fine_which_is_why_this_was_hard():
    """oolite.exe's own imports all resolve even on the broken PATH - the trap, pinned.

    This is the observation that sent the original diagnosis down a dead end, so it is worth
    asserting rather than remembering: a check limited to the executable's direct imports reports
    a clean bill of health on exactly the configuration that cannot launch.
    """
    missing = state_dump.unresolved_imports(APP_DIR, roots=("oolite.exe",))
    assert missing == {}, (
        "oolite.exe's own import table is expected to resolve; if this fails the build is broken "
        "in a different and more basic way than the oo-gla incident: %s" % missing
    )


@needs_build
def test_walker_finds_the_gallium_deps_when_the_runtime_dir_is_absent_from_path(monkeypatch):
    """With the UCRT64 dir off PATH, the walker must name the three DLLs and blame gallium."""
    runtime = _runtime_dir()
    if runtime is None:
        pytest.skip("no runtime directory on this host supplies the gallium dependencies")
    stripped = os.pathsep.join(
        d for d in os.environ.get("PATH", "").split(os.pathsep)
        if d and os.path.abspath(d).lower() != runtime.lower()
    )
    monkeypatch.setenv("PATH", stripped)

    missing = state_dump.unresolved_imports(APP_DIR)
    assert {m.lower() for m in missing} == GALLIUM_DEPS, missing
    # and every one of them must be attributed to libgallium_wgl.dll, not to the exe
    for name, importers in missing.items():
        assert importers == {"libgallium_wgl.dll"}, (name, importers)


@needs_build
def test_walker_is_clean_once_the_runtime_dir_is_on_path(monkeypatch):
    """The positive control: the SAME walk on the SAME build reports nothing missing.

    Without this half, a walker that simply always reported three missing DLLs would pass the
    test above - the pair is what shows the walker is measuring PATH rather than asserting a
    constant.
    """
    runtime = _runtime_dir()
    if runtime is None:
        pytest.skip("no runtime directory on this host supplies the gallium dependencies")
    monkeypatch.setenv("PATH", runtime + os.pathsep + os.environ.get("PATH", ""))
    assert state_dump.unresolved_imports(APP_DIR) == {}


@needs_build
def test_preflight_repairs_path_and_is_idempotent(monkeypatch):
    """ensure_launchable puts the runtime dir back on PATH, and a second call is a no-op."""
    runtime = _runtime_dir()
    if runtime is None:
        pytest.skip("no runtime directory on this host supplies the gallium dependencies")
    stripped = os.pathsep.join(
        d for d in os.environ.get("PATH", "").split(os.pathsep)
        if d and os.path.abspath(d).lower() != runtime.lower()
    )
    monkeypatch.setenv("PATH", stripped)

    added = state_dump.ensure_launchable(APP_DIR, verbose=False)
    assert added, "preflight repaired nothing on a PATH that provably cannot launch the game"
    assert state_dump.unresolved_imports(APP_DIR) == {}
    # Second call: already launchable, so it must add nothing at all.
    assert state_dump.ensure_launchable(APP_DIR, verbose=False) == []


@needs_build
def test_preflight_raises_a_named_error_when_no_directory_can_supply_the_dlls(monkeypatch):
    """The unfixable case must fail FAST and LOUD, naming the DLLs - never silent retries.

    The whole point of the preflight is that a missing runtime directory is not a race: burning
    eight backoffs (~116s) on it and then reporting a bare exit code is what made the original
    incident cost an hour to diagnose.
    """
    runtime = _runtime_dir()
    if runtime is None:
        pytest.skip("no runtime directory on this host supplies the gallium dependencies")
    stripped = os.pathsep.join(
        d for d in os.environ.get("PATH", "").split(os.pathsep)
        if d and os.path.abspath(d).lower() != runtime.lower()
    )
    monkeypatch.setenv("PATH", stripped)
    monkeypatch.setattr(state_dump, "_candidate_runtime_dirs", lambda: [])

    with pytest.raises(state_dump.LaunchEnvironmentError) as excinfo:
        state_dump.ensure_launchable(APP_DIR, verbose=False)

    message = str(excinfo.value)
    for dll in GALLIUM_DEPS:
        assert dll in message.lower(), "error does not name %s: %s" % (dll, message)
    assert str(state_dump.STATUS_DLL_NOT_FOUND) in message
    assert "no retry can fix it" in message


def test_status_dll_not_found_constant_matches_the_observed_exit_code():
    """The literal from the incident report, pinned against the symbolic constant."""
    assert state_dump.STATUS_DLL_NOT_FOUND == 3221225781
    assert state_dump.STATUS_DLL_NOT_FOUND == 0xC0000135


def test_run_dump_calls_the_preflight_before_launching():
    """Falsifiability: the preflight is only worth anything if run_dump actually invokes it.

    Asserted on the AST, not on a substring - this module's own prose mentions
    ensure_launchable many times, and a source-text grep of run_dump.py could be satisfied by a
    comment or the import line alone (fleet learning from oo-07s).
    """
    import ast

    tree = ast.parse(open(os.path.join(HERE, "run_dump.py"), encoding="utf-8").read())
    main = next(
        (n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "main"), None
    )
    assert main is not None, "run_dump.py has no main()"
    calls = [
        n for n in ast.walk(main)
        if isinstance(n, ast.Call) and isinstance(n.func, ast.Name)
        and n.func.id == "ensure_launchable"
    ]
    assert calls, "run_dump.main() never calls ensure_launchable(); the preflight is dead code"
