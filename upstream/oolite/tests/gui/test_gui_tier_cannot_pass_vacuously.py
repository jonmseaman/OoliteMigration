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
