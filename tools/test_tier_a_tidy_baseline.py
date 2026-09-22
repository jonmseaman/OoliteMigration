"""tools/tier-a-tidy-baseline.py: pre-existing clang-tidy findings pass, new ones fail (bead oo-utqt)."""
import subprocess
import sys
from pathlib import Path

SCRIPT = Path(__file__).with_name("tier-a-tidy-baseline.py")
BASE = "int a(void);\nstatic int b(int x) { return 0; }\n"


def run(tmp_path, source, baseline, tidy):
    (tmp_path / "src.m").write_text(source)
    (tmp_path / "base.m").write_text(baseline)
    (tmp_path / "tidy.txt").write_text(tidy)
    return subprocess.run([sys.executable, str(SCRIPT), str(tmp_path / "src.m"),
                           str(tmp_path / "base.m"), str(tmp_path / "tidy.txt")],
                          capture_output=True, text=True).returncode


def finding(line):
    return f"src.m:{line}:5: error: parameter 'x' is unused [misc-unused-parameters,-warnings-as-errors]\n"


def test_finding_on_unchanged_line_passes(tmp_path):
    assert run(tmp_path, BASE, BASE, finding(2)) == 0


def test_finding_on_moved_but_unchanged_line_passes(tmp_path):
    assert run(tmp_path, "// added\n" + BASE, BASE, finding(3)) == 0


def test_finding_on_edited_line_fails(tmp_path):
    edited = BASE.replace("return 0", "return 1")
    assert run(tmp_path, edited, BASE, finding(2)) == 1


def test_new_file_has_no_baseline(tmp_path):
    assert run(tmp_path, BASE, "", finding(2)) == 1


def test_unparseable_tidy_failure_is_not_a_pass(tmp_path):
    assert run(tmp_path, BASE, BASE, "clang-tidy: crashed\n") == 2
