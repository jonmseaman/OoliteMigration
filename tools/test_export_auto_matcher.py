#!/usr/bin/env python3
"""The export.auto value matcher in tools/check-beads-db-merge.sh (bead oo-ehyx).

WHAT THIS PINS
--------------
Step 4/4 of tools/check-beads-db-merge.sh asserts `export.auto` is false in
.beads/config.yaml.  It has had three shapes:

  1. `awk ... | grep -qE '^\\s*auto:\\s*false'` -- a `producer | grep -q` under
     pipefail, i.e. the class bead oo-mxgy audited, and UNANCHORED at the end.
  2. oo-mxgy removed the pipeline (right) and compared the extracted value
     EXACTLY (`[ "$val" = "false" ]`).  That fixed `auto: falsey` matching, but
     it also broke `auto: false   # keep exports manual` -- a perfectly legal
     end-of-line YAML comment -- which made the guard die with the FALSE message
     "export.auto is not false in .beads/config.yaml".
  3. oo-ehyx (this) strips a trailing comment before the compare, KEEPING the
     `falsey` tightening.

WHY IT RUNS THE REAL SHELL BLOCK
--------------------------------
A Python reimplementation of the matcher would be a second, untested copy: it
could agree with the table here and disagree with the script, which is the exact
failure the fleet keeps rediscovering (a matcher right in a unit test and unwired
in the script is not a fix).  So the block is EXTRACTED from
tools/check-beads-db-merge.sh between its BEGIN/END markers and executed by bash,
verbatim, under `set -euo pipefail` -- the same options line 24 of the script
sets.  If someone edits the block, these tests exercise the edit; if someone
deletes the markers, test_matcher_block_is_extractable_from_the_script goes RED.

Run:  python3 -m pytest tools/test_export_auto_matcher.py -q
"""
from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import pytest

TOOLS = Path(__file__).resolve().parent
REPO = TOOLS.parent
SCRIPT = TOOLS / "check-beads-db-merge.sh"
BEGIN = ">>> BEGIN export.auto matcher"
END = "<<< END export.auto matcher"


def _matcher_block() -> str:
    lines = SCRIPT.read_text(encoding="utf-8", errors="replace").splitlines()
    starts = [i for i, l in enumerate(lines) if BEGIN in l]
    ends = [i for i, l in enumerate(lines) if END in l]
    assert len(starts) == 1 and len(ends) == 1 and starts[0] < ends[0], (
        f"{SCRIPT.name} must carry exactly one '{BEGIN}' ... '{END}' pair around the "
        f"export.auto value extraction, so these tests run the REAL code instead of a "
        f"second copy of it. Found {len(starts)} begin / {len(ends)} end marker(s)."
    )
    return "\n".join(lines[starts[0] + 1:ends[0]])


def _bash() -> str:
    exe = shutil.which("bash")
    if not exe:
        pytest.skip("no bash on PATH")
    return exe


def auto_off(cfgline: str) -> bool:
    """Run the script's own matcher over one config line; True == 'auto is false'."""
    prog = (
        "set -euo pipefail\n"
        "auto_off=0\n"
        "while IFS= read -r cfgline; do\n"
        f"{_matcher_block()}\n"
        'done <<"XEOFX"\n'
        f"{cfgline}\n"
        "XEOFX\n"
        'printf %s "$auto_off"\n'
    )
    r = subprocess.run([_bash(), "-c", prog], capture_output=True, text=True)
    assert r.returncode == 0, f"matcher block exited {r.returncode}: {r.stderr!r}"
    assert r.stdout in ("0", "1"), f"unexpected auto_off={r.stdout!r}"
    return r.stdout == "1"


# The measured table this bead is judged on. True == MATCH (auto is false).
CASES = [
    ("    auto: false", True, "the live config's shape"),
    ("    auto: false   # keep exports manual", True, "THE REGRESSION oo-ehyx fixes: a legal trailing YAML comment"),
    ("    auto: false# nospace", False, "no space before '#': YAML plain scalar 'false# nospace', not a comment"),
    ("    auto: falsey", False, "the oo-mxgy tightening, deliberately PRESERVED"),
    ("    auto: true", False, "the setting the guard exists to catch"),
    ("    auto: true   # x", False, "a comment must not rescue a true value"),
    ("    auto:false", True, "no space after the colon; bd/YAML-lax, matched by every shape of this check"),
    ("    auto:   false   ", True, "extra internal and trailing whitespace"),
    ("    # auto: false", False, "WHOLE LINE COMMENTED OUT: a disabled setting must never satisfy the guard"),
]


@pytest.mark.parametrize("line,expected,why", CASES, ids=[c[0].strip() for c in CASES])
def test_export_auto_matcher(line, expected, why):
    got = auto_off(line)
    assert got == expected, (
        f"{line!r}: matcher says {'MATCH' if got else 'NOMATCH'}, expected "
        f"{'MATCH' if expected else 'NOMATCH'} -- {why}"
    )


def test_matcher_block_is_extractable_from_the_script():
    """Anti-vacuity: every test above is meaningless if the block is not the real one."""
    block = _matcher_block()
    assert "auto:" in block and "false" in block, block
    assert "|" not in block.replace("||", ""), (
        "the export.auto extraction has reacquired a pipeline. This script sets "
        "`set -euo pipefail`, where `producer | grep -q` reports a SUCCESSFUL match as "
        "exit 141 (bead oo-mxgy). Keep the extraction pure shell."
    )


def test_the_trailing_comment_is_the_only_thing_stripped():
    """A '#' inside the value is not a comment, so the guard must not be loosened into
    accepting anything that merely STARTS with 'false'."""
    assert not auto_off("    auto: false x")
    assert not auto_off("    auto: false,")
    assert not auto_off("    auto: \"false\"   # quoted is a different scalar")


def test_live_config_still_satisfies_the_guard():
    """End-to-end premise: the real .beads/config.yaml must pass the matcher.

    Mirrors the script's own awk over the `export:` block so a config reshuffle that
    moves `auto:` out of that block is caught here rather than in a guard run.
    """
    cfg = REPO / ".beads" / "config.yaml"
    if not cfg.exists():
        pytest.skip("no .beads/config.yaml in this tree")
    prog = (
        "set -euo pipefail\n"
        "cd \"$1\"\n"
        "export_block=\"$(awk '/^export:/{f=1;next} f&&/^[^ ]/{f=0} f' .beads/config.yaml)\"\n"
        "auto_off=0\n"
        "while IFS= read -r cfgline; do\n"
        f"{_matcher_block()}\n"
        'done <<XEOFX\n'
        "$export_block\n"
        "XEOFX\n"
        'printf %s "$auto_off"\n'
    )
    r = subprocess.run([_bash(), "-c", prog, "x", str(REPO)], capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    assert r.stdout == "1", (
        "the live .beads/config.yaml no longer sets export.auto false inside its `export:` "
        "block; tools/check-beads-db-merge.sh step 4/4 would fail."
    )
