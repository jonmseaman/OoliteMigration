"""tools/tier-a-tidy-baseline.py: pre-existing clang-tidy findings pass, new ones fail (bead oo-utqt).

Bead oo-3rb.60 deliberately changed the tool's interface from three arguments to five
(<source> <baseline-copy> <tidy-output> <repo-root> <base-ref>) and keyed findings by (path, line);
it refuses the old three-argument call. Bead oo-3rb.167 moved these tests to that contract: the
original five cases are unchanged in what they prove, and the path-aware cases below pin the new
behaviour. The oo-3rb.60 tidy probe script remains the end-to-end check through tidy_gate.
"""
import subprocess
import sys
from pathlib import Path

SCRIPT = Path(__file__).with_name("tier-a-tidy-baseline.py")
BASE = "int a(void);\nstatic int b(int x) { return 0; }\n"
HEADER = "#pragma once\n#include \"cycle.h\"\nint h(int y);\n"


def git(root, *args):
    subprocess.run(["git", "-C", str(root), "-c", "user.name=t", "-c", "user.email=t@t",
                    "-c", "commit.gpgsign=false", *args], check=True, capture_output=True)


def run(tmp_path, source, baseline, tidy, base_ref="HEAD", argv=None):
    (tmp_path / "src.m").write_text(source)
    (tmp_path / "base.m").write_text(baseline)
    (tmp_path / "tidy.txt").write_text(tidy)
    args = argv if argv is not None else [str(tmp_path / "src.m"), str(tmp_path / "base.m"),
                                          str(tmp_path / "tidy.txt"), str(tmp_path), base_ref]
    # cwd=tmp_path: clang-tidy names files as the compile command spelled them; a relative
    # "src.m" in a finding resolves against the directory it ran in.
    return subprocess.run([sys.executable, str(SCRIPT), *args], cwd=tmp_path,
                          capture_output=True, text=True).returncode


def finding(line, path="src.m"):
    return f"{path}:{line}:5: error: parameter 'x' is unused [misc-unused-parameters,-warnings-as-errors]\n"


def header_repo(tmp_path, header_now):
    """tmp_path as a git repo whose base commit holds HEADER as h.h; the worktree holds header_now."""
    git(tmp_path, "init", "-q")
    (tmp_path / "h.h").write_text(HEADER)
    git(tmp_path, "add", "h.h")
    git(tmp_path, "commit", "-q", "-m", "base")
    (tmp_path / "h.h").write_text(header_now)


# ------------------------------------------------------------ findings in the source under test

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


# ------------------------------------------------------------ the five-argument contract (oo-3rb.60)

def test_old_three_argument_call_is_refused(tmp_path):
    argv = [str(tmp_path / "src.m"), str(tmp_path / "base.m"), str(tmp_path / "tidy.txt")]
    assert run(tmp_path, BASE, BASE, finding(2), argv=argv) == 2


def test_header_finding_on_unchanged_header_line_passes_though_source_line_edited(tmp_path):
    """The oo-3rb.60 defect: h.h:2 was judged against line 2 of the (edited) source."""
    header_repo(tmp_path, HEADER)
    edited = BASE.replace("return 0", "return 1")
    assert run(tmp_path, edited, BASE, finding(2, "h.h")) == 0


def test_header_finding_on_edited_header_line_fails_though_source_line_unchanged(tmp_path):
    """The symmetric half: a new header finding must not hide behind an unchanged source line."""
    header_repo(tmp_path, HEADER.replace("cycle.h", "cycle2.h"))
    assert run(tmp_path, BASE, BASE, finding(2, "h.h")) == 1


def test_finding_in_file_absent_at_base_ref_is_new(tmp_path):
    header_repo(tmp_path, HEADER)
    (tmp_path / "fresh.h").write_text(HEADER)
    assert run(tmp_path, BASE, BASE, finding(2, "fresh.h")) == 1


def test_finding_outside_repo_root_is_pre_existing(tmp_path):
    root = tmp_path / "repo"
    root.mkdir()
    (tmp_path / "sys.h").write_text(HEADER)
    (root / "tidy.txt").write_text(finding(2, str(tmp_path / "sys.h")))
    (root / "src.m").write_text(BASE)
    (root / "base.m").write_text(BASE)
    rc = subprocess.run([sys.executable, str(SCRIPT), str(root / "src.m"), str(root / "base.m"),
                         str(root / "tidy.txt"), str(root), "HEAD"], cwd=root,
                        capture_output=True, text=True).returncode
    assert rc == 0


def test_unreadable_base_ref_is_not_a_verdict(tmp_path):
    header_repo(tmp_path, HEADER)
    assert run(tmp_path, BASE, BASE, finding(2, "h.h"), base_ref="no-such-ref") == 2
