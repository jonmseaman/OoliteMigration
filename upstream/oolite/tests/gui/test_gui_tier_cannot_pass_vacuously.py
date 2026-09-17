"""The tier's own guard against reporting a pass for a run that never happened.

These tests are `offline`: no desktop, no built game, no pyautogui. They exist because the
failure they cover is invisible by construction — when the GUI tier skips, every command in the
DoD path still exits 0, and the only way to notice is to assert on the skip machinery itself.

Bug oo-7by1: `pytest.importorskip("pyautogui")` inside the `game` fixture meant the G1 DoD
command exited 0 green on three separate configurations where G1 never executed (non-Windows;
Windows without pyautogui; and any machine at all, since nothing installed requirements.txt).
"""

import ast
import os
import subprocess
import sys

import pytest

import conftest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
RUNNER = os.path.join(REPO_ROOT, "tools", "gui-tier.sh")


@pytest.mark.offline
def test_no_importorskip_anywhere_in_the_tier():
    """A hard dependency must fail, not skip.

    importorskip turns a broken environment into a green run. If this assertion ever needs
    relaxing, the thing being imported is by definition not a hard dependency of this tier.
    """
    for name in sorted(os.listdir(HERE)):
        if not name.endswith(".py"):
            continue
        with open(os.path.join(HERE, name), "r", encoding="utf-8") as handle:
            tree = ast.parse(handle.read(), filename=name)
        called = {
            node.func.attr if isinstance(node.func, ast.Attribute) else getattr(node.func, "id", "")
            for node in ast.walk(tree)
            if isinstance(node, ast.Call)
        }
        assert "importorskip" not in called, (
            f"{name} calls pytest.importorskip; a missing hard dependency in this tier must "
            "fail with the install command, not skip to a silent pass (oo-7by1)"
        )


@pytest.mark.offline
def test_missing_pyautogui_fails_rather_than_skips(monkeypatch):
    """With pyautogui unimportable, the dependency gate raises Failed, not Skipped."""
    # A None entry in sys.modules is exactly how CPython reports "this import fails".
    monkeypatch.setitem(sys.modules, "pyautogui", None)

    with pytest.raises(BaseException) as caught:
        conftest.require_gui_dependencies()

    assert not isinstance(caught.value, pytest.skip.Exception), (
        "a missing pyautogui skipped instead of failing"
    )
    assert isinstance(caught.value, pytest.fail.Exception), (
        f"expected a hard failure, got {type(caught.value).__name__}"
    )
    message = str(caught.value)
    assert "pip install -r" in message, "the failure must name the exact install command"
    assert "requirements.txt" in message


@pytest.mark.offline
def test_requirements_names_the_tier_dependencies():
    with open(os.path.join(HERE, "requirements.txt"), "r", encoding="utf-8") as handle:
        names = {line.split("=")[0].split(">")[0].strip().lower() for line in handle if line.strip()}
    assert "pyautogui" in names
    assert "pytest" in names


@pytest.mark.offline
def test_a_runner_installs_the_requirements():
    """requirements.txt must be installed by something the DoD path actually runs.

    Vendoring the dependency, or documenting the install in prose nobody executes, both leave
    the missing-pyautogui case as the expected case.
    """
    assert os.path.isfile(RUNNER), "tools/gui-tier.sh is the tier's runner and must exist"
    with open(RUNNER, "r", encoding="utf-8") as handle:
        script = handle.read()
    assert "requirements.txt" in script
    assert "pip install" in script
    assert "OO_GUI_REQUIRE=1" in script, (
        "the runner must disarm the not-applicable-platform skip, or it can still exit 0 green "
        "on a machine that never ran G1"
    )
    if os.name != "nt":
        bash = ["bash", "-n", RUNNER]
        assert subprocess.run(bash, capture_output=True).returncode == 0, "runner is not valid bash"


@pytest.mark.offline
def test_wrong_platform_skip_is_a_failure_when_the_run_demanded_g1(monkeypatch):
    """OO_GUI_REQUIRE=1 (what the runner exports) removes the last vacuous-pass path."""
    gate = conftest.require_gui_platform
    monkeypatch.setattr(conftest, "IS_WINDOWS", False)

    monkeypatch.setattr(conftest, "GUI_REQUIRED", False)
    with pytest.raises(pytest.skip.Exception) as skipped:
        gate()
    assert "ADR-0017" in str(skipped.value), "the one legitimate skip must say why"

    monkeypatch.setattr(conftest, "GUI_REQUIRED", True)
    with pytest.raises(BaseException) as caught:
        gate()
    assert isinstance(caught.value, pytest.fail.Exception), (
        "with OO_GUI_REQUIRE set, the wrong platform must fail, not skip"
    )


@pytest.mark.offline
def test_oo_gui_require_is_honoured_by_the_fixture_source():
    """The env var has to reach the non-Windows branch, not merely exist."""
    with open(os.path.join(HERE, "conftest.py"), "r", encoding="utf-8") as handle:
        source = handle.read()
    assert "OO_GUI_REQUIRE" in source
    gate = source.split("def require_gui_platform(", 1)[1].split("\ndef ", 1)[0]
    assert "GUI_REQUIRED" in gate, "the precondition gate must consult OO_GUI_REQUIRE"
    runtime = source.split("def gui_runtime(", 1)[1].split("\n@pytest.fixture", 1)[0]
    assert "require_gui_platform()" in runtime
    assert "require_gui_dependencies()" in runtime
    # And the gate must be wired into the fixture the real test actually uses, first, so the
    # platform skip is reachable without a built game.
    game_sig = source.split("def game(", 1)[1].split(")", 1)[0]
    assert game_sig.split(",")[0].strip() == "gui_runtime"


# --- bug oo-5rsa: the three post-exit hygiene checks must be able to FAIL ----------------------
#
# assert_clean_exit promised "no core dump, no ERROR in Latest.log, and a defaults file that still
# parses", and the story (docs/stories/G1-exit-via-mouse.md:13,46) additionally requires "no
# orphaned process". Three of those were missing or true by construction:
#
#   * the defaults re-parse was never implemented at all;
#   * `if os.path.isfile(log):` meant an ABSENT Latest.log silently passed the log check, even
#     though _await_startup_complete had already proved that file existed in the same run;
#   * `assert game.proc.poll() == 0` only re-read a returncode wait() had already reaped, so it
#     could not return anything else.
#
# A check that cannot fail is not a check. Each test below CONSTRUCTS the failure and asserts the
# check notices it, so none of the three can silently revert to a tautology.


def _healthy_output_dir(tmp_path):
    out = tmp_path / "out"
    out.mkdir(exist_ok=True)
    (out / "Latest.log").write_text(
        "[log.header] Opening log\n"
        "[display.initGL] Requested a new surface of 960 x 720, windowed\n"
        "[searchPaths.dumpAll] Resource paths\n"
        "[shipData.load.begin] Loading ship data\n"
        "[startup.complete] Startup complete\n"
        "[exit.context] Exiting: exit game.\n",
        encoding="utf-8",
    )
    return str(out)


def _healthy_app_dir(tmp_path):
    """An app dir holding a defaults file in the dialect gnustep-base really writes.

    The shape of upstream/oolite/build/meson_test/oolite.app/GNUstep/Defaults/oolite.plist as
    written by a real run on this machine: OpenStep ("old-style"), not XML.
    """
    app = tmp_path / "oolite.app"
    defaults = app / "GNUstep" / "Defaults"
    defaults.mkdir(parents=True, exist_ok=True)
    (defaults / "oolite.plist").write_text(
        '{\n'
        '    "debug-settings-override" = {\n'
        '    };\n'
        '    "volume_control" = "0.5";\n'
        '    window_height = 720;\n'
        '    window_width = 960;\n'
        '}\n',
        encoding="utf-8",
    )
    return str(app)


@pytest.mark.offline
def test_the_real_defaults_dialect_parses(tmp_path):
    """The healthy case must PASS - a check that rejects a good file is no use either.

    gnustep-base emits OpenStep, so a check built on plistlib alone would fail every real file.
    """
    path, contents = conftest.assert_defaults_file_reparses(_healthy_app_dir(tmp_path))
    assert contents["window_width"] == "960"
    assert contents["debug-settings-override"] == {}
    assert path.endswith(os.path.join("GNUstep", "Defaults", "oolite.plist"))


@pytest.mark.offline
def test_assert_clean_exit_accepts_a_healthy_run(tmp_path):
    conftest.assert_clean_exit(_healthy_output_dir(tmp_path), _healthy_app_dir(tmp_path))


@pytest.mark.offline
def test_a_missing_defaults_file_fails(tmp_path):
    """FAILURE 1a: the defaults file is not written at all."""
    out = _healthy_output_dir(tmp_path)
    app = _healthy_app_dir(tmp_path)
    os.remove(os.path.join(app, "GNUstep", "Defaults", "oolite.plist"))
    with pytest.raises(AssertionError) as caught:
        conftest.assert_clean_exit(out, app)
    assert "defaults" in str(caught.value).lower()


@pytest.mark.offline
@pytest.mark.parametrize(
    "corruption",
    [
        '{\n    "volume_control" = "0.5";\n',      # truncated: no closing brace
        '{\n    "volume_control" = "0.5\n}\n',      # unterminated string
        '{\n    "volume_control" "0.5";\n}\n',      # missing =
        '',                                        # zero bytes
        '{} trailing garbage here',                # trailing junk
        '{\n    "k" = ;\n}\n',                     # missing value
    ],
)
def test_a_corrupt_defaults_file_fails(tmp_path, corruption):
    """FAILURE 1b: the defaults file exists but the final write did not complete."""
    out = _healthy_output_dir(tmp_path)
    app = _healthy_app_dir(tmp_path)
    plist = os.path.join(app, "GNUstep", "Defaults", "oolite.plist")
    with open(plist, "w", encoding="utf-8") as handle:
        handle.write(corruption)
    with pytest.raises(AssertionError) as caught:
        conftest.assert_clean_exit(out, app)
    message = str(caught.value).lower()
    assert "defaults" in message or "empty" in message, f"{corruption!r} passed silently"


@pytest.mark.offline
def test_an_absent_log_fails_rather_than_skipping(tmp_path):
    """FAILURE 2: Latest.log is gone. This used to SILENTLY PASS.

    `if os.path.isfile(log):` made the log check evaporate whenever the file it reads was
    absent - and the ERROR scan is the one check with a real chance of catching a bad
    shutdown. _await_startup_complete already read startup.complete out of this exact file in
    this exact run, so its absence is a broken run, not a reason to check nothing.
    """
    out = _healthy_output_dir(tmp_path)
    app = _healthy_app_dir(tmp_path)
    os.remove(os.path.join(out, "Latest.log"))
    with pytest.raises(AssertionError) as caught:
        conftest.assert_clean_exit(out, app)
    assert "Latest.log" in str(caught.value)


@pytest.mark.offline
def test_an_error_in_the_log_still_fails(tmp_path):
    """The check that the absent-log skip was hiding must itself still work."""
    out = _healthy_output_dir(tmp_path)
    app = _healthy_app_dir(tmp_path)
    with open(os.path.join(out, "Latest.log"), "a", encoding="utf-8") as handle:
        handle.write("[shipData.load.error] ERROR: ship data did not load\n")
    with pytest.raises(AssertionError) as caught:
        conftest.assert_clean_exit(out, app)
    assert "errors in Latest.log" in str(caught.value)


@pytest.mark.offline
def test_a_crash_dump_still_fails(tmp_path):
    out = _healthy_output_dir(tmp_path)
    app = _healthy_app_dir(tmp_path)
    with open(os.path.join(out, "oolite.dmp"), "wb") as handle:
        handle.write(b"\x00")
    with pytest.raises(AssertionError) as caught:
        conftest.assert_clean_exit(out, app)
    assert "crash dump" in str(caught.value)


@pytest.mark.offline
def test_the_no_survivor_check_is_not_a_tautology(monkeypatch):
    """FAILURE 3: a live process in the launched tree must fail the check.

    The old `assert game.proc.poll() == 0` re-read a returncode wait() had already stored, so
    it was true by construction. The OS process table is the only witness that can say no.
    Here the table is stubbed to pin down the SCOPING rule exactly; the real table reader is
    exercised against a live process by the two tests below.
    """
    live = [
        (1000, 4, "explorer.exe"),
        (1001, 1000, "oolite.exe"),     # our root
        (1002, 1001, "oolite.exe"),     # a child of ours - also a survivor
        (2001, 1000, "oolite.exe"),     # a CONCURRENT SIBLING run - must NOT be blamed on us
    ]
    monkeypatch.setattr(conftest, "_process_table", lambda: live)
    survivors = conftest.surviving_game_processes(1001)
    assert survivors == [(1001, "oolite.exe"), (1002, "oolite.exe")], survivors
    assert 2001 not in [pid for pid, _ in survivors], (
        "a concurrent sibling GUI run's process was mistaken for our leak"
    )
    with pytest.raises(AssertionError) as caught:
        conftest.assert_no_surviving_game_processes(1001, timeout=0.0)
    assert "orphaned game process" in str(caught.value)

    # And with our own tree gone, the sibling alone must NOT fail the check.
    monkeypatch.setattr(
        conftest, "_process_table", lambda: [(1000, 4, "explorer.exe"), (2001, 1000, "oolite.exe")]
    )
    conftest.assert_no_surviving_game_processes(1001, timeout=0.0)


@pytest.mark.offline
def test_the_process_table_sees_this_very_process():
    """The real table reader works on this platform: it must find our own pid."""
    rows = conftest._process_table()
    mine = [row for row in rows if row[0] == os.getpid()]
    assert mine, "the process table reader did not find this python process"
    _, parent, name = mine[0]
    assert name, "implausible empty image name for our own pid"
    assert parent > 0


@pytest.mark.offline
def test_a_real_live_child_is_seen_as_a_survivor(monkeypatch):
    """End-to-end on the REAL OS table: a live child is found, and once dead it is not.

    Uses this python's own image name rather than oolite.exe (which cannot be launched from an
    offline test), so the tree walk and the liveness reading are exercised for real.
    """
    child = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)"])
    try:
        monkeypatch.setattr(
            conftest, "GAME_PROCESS_NAMES", (os.path.basename(sys.executable).lower(),)
        )
        survivors = conftest.surviving_game_processes(child.pid)
        assert child.pid in [pid for pid, _ in survivors], (
            f"a live child (pid {child.pid}) was not reported as a survivor: {survivors}"
        )
        with pytest.raises(AssertionError):
            conftest.assert_no_surviving_game_processes(child.pid, timeout=0.0)
        child.kill()
        child.wait(timeout=30)
        conftest.assert_no_surviving_game_processes(child.pid, timeout=10.0)
    finally:
        if child.poll() is None:
            child.kill()
            child.wait(timeout=30)


@pytest.mark.offline
def test_g1_asserts_on_the_process_table_not_on_returncode():
    """The tautology must not come back: no `proc.poll()`/`returncode` comparison after wait().

    AST, not grep: the comment explaining why the old assertion was a tautology contains the
    very text a grep would look for.
    """
    path = os.path.join(HERE, "test_g1_exit_via_mouse.py")
    with open(path, "r", encoding="utf-8") as handle:
        source = handle.read()
    tree = ast.parse(source)
    func = next(
        node
        for node in ast.walk(tree)
        if isinstance(node, ast.FunctionDef) and node.name == "test_g1_exit_via_mouse"
    )
    wait_line = min(
        node.lineno
        for node in ast.walk(func)
        if isinstance(node, ast.Call)
        and isinstance(node.func, ast.Attribute)
        and node.func.attr == "wait"
    )
    for node in ast.walk(func):
        if not isinstance(node, ast.Assert) or node.lineno <= wait_line:
            continue
        offenders = [
            sub
            for sub in ast.walk(node.test)
            if (isinstance(sub, ast.Attribute) and sub.attr in ("poll", "returncode"))
            or (
                isinstance(sub, ast.Call)
                and isinstance(sub.func, ast.Attribute)
                and sub.func.attr == "poll"
            )
        ]
        assert not offenders, (
            "line %d re-reads the Popen handle's own returncode, which wait() already reaped; "
            "that comparison cannot fail. Enumerate the surviving processes instead (oo-5rsa)"
            % node.lineno
        )
    calls = {
        node.func.id
        for node in ast.walk(func)
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
    }
    assert "assert_no_surviving_game_processes" in calls
    assert "assert_clean_exit" in calls
    assert "oolite.exe" in conftest.GAME_PROCESS_NAMES


@pytest.mark.offline
def test_assert_clean_exit_runs_every_check_unconditionally():
    """No `if` may guard a check inside assert_clean_exit, and all three must be present.

    A skip is a silent pass; a check wrapped in "only if the evidence happens to be there" is
    the same thing spelled differently.
    """
    with open(os.path.join(HERE, "conftest.py"), "r", encoding="utf-8") as handle:
        source = handle.read()
    tree = ast.parse(source)
    func = next(
        node
        for node in ast.walk(tree)
        if isinstance(node, ast.FunctionDef) and node.name == "assert_clean_exit"
    )
    assert not [n for n in ast.walk(func) if isinstance(n, (ast.If, ast.IfExp))], (
        "assert_clean_exit must run every check unconditionally; an absent Latest.log must "
        "FAIL, not skip the log check (oo-5rsa)"
    )
    body = ast.get_source_segment(source, func) or ""
    assert "assert_defaults_file_reparses" in body, (
        "the promised defaults re-parse must actually be performed (oo-5rsa)"
    )
    assert "crash dump" in body
    assert "Latest.log" in body
