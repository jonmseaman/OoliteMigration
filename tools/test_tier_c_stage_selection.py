#!/usr/bin/env python3
"""Regression tests for tools/tier-c.sh's --only / --skip stage selection (bead oo-3uf8).

THE DEFECT THESE PIN. `--only jsapi` and `--skip gui` rejected EVERY stage name with
`tier-c: no such stage 'jsapi'; known stages: tier-b jsapi asan ...` -- naming the stage as
known in the same sentence it refused it. The validation was
`all_stage_names | grep -qx "$want"` under the `set -o pipefail` at the top of tier-c.sh:
`grep -q` exits the instant it matches, SIGPIPEs the still-writing producer on the left, and
pipefail propagates 141, so a SUCCESSFUL match read as a failure. Same class as bead oo-j4u
(and fleet learning oo-j4u), one level in: there it was an acceptance line, here the product.

WHY A TOY REPRO CANNOT STAND IN FOR THESE TESTS, and why they drive the REAL script:
`printf 'a\\nb\\n' | grep -qx a` returns 0 with AND without pipefail, because a small producer
fits in the 64 KB pipe buffer and finishes writing before grep exits, so it is never signalled.
Only tier-c.sh's own producer -- a subshell running a `while read` loop over the STAGES table --
is still scheduled when grep returns. A minimal fixture would be green on the broken code.

BOTH DIRECTIONS ARE PINNED, deliberately. A "fix" that makes the validator accept everything
satisfies the valid-name tests and is worthless, so the invalid-name tests are the load-bearing
half: an unknown stage must still be FATAL (rc=2, never a vacuous "GREEN, 0 stages").

Every test is offline: --dry-run prints the plan and runs no stage, no build and no game.

Run:  python3 -m pytest tools/test_tier_c_stage_selection.py -q
"""
from __future__ import annotations

import re
import subprocess
from pathlib import Path

import pytest

TOOLS = Path(__file__).resolve().parent
REPO_ROOT = TOOLS.parent
TIER_C = TOOLS / "tier-c.sh"

# The stages tier-c.sh declares. Kept as a literal so a table someone quietly narrowed does not
# also narrow this test's own expectations -- test_every_declared_stage_is_covered_here ties the
# two together and fails if they drift.
STAGES = ["tier-b", "jsapi", "asan", "goldens", "corpus", "gui", "fleetdata"]


def tier_c(*args: str) -> subprocess.CompletedProcess:
    """Run the real tools/tier-c.sh under `bash -o pipefail`, as accept.sh does (accept.sh:76).

    pipefail is not incidental here: it is the exact shell setting that turned the SIGPIPE from
    `grep -q` into a rejection, so a test that ran without it could pass on the broken script.
    """
    return subprocess.run(
        ["bash", "-o", "pipefail", str(TIER_C), *args],
        capture_output=True, text=True, timeout=180, cwd=str(REPO_ROOT),
    )


def plan_of(proc: subprocess.CompletedProcess) -> list[str]:
    """The stage list tier-c PRINTED, parsed out of its --dry-run plan line."""
    m = re.search(r"^tier-c: plan \((\d+) stage\(s\)\): (.*)$", proc.stdout, re.M)
    assert m, f"no plan line in stdout:\n{proc.stdout}\n{proc.stderr}"
    names = m.group(2).split()
    assert len(names) == int(m.group(1)), (
        f"the plan line says {m.group(1)} stage(s) but lists {len(names)}: {names}")
    return names


# ------------------------------------------------------- the valid-name direction (the defect)


@pytest.mark.parametrize("stage", STAGES)
def test_only_accepts_every_declared_stage_name(stage: str) -> None:
    """--only <stage> must select exactly that stage, for EVERY name tier-c lists as known.

    This is the regression itself: before the fix each of these died rc=2 with
    "no such stage '<stage>'" while printing <stage> in its own list of known stages.
    """
    proc = tier_c("--only", stage, "--dry-run")
    assert proc.returncode == 0, (
        f"--only {stage} exited {proc.returncode}; tier-c refused a stage from its own table.\n"
        f"stderr: {proc.stderr}")
    assert plan_of(proc) == [stage]


@pytest.mark.parametrize("stage", STAGES)
def test_skip_accepts_every_declared_stage_name(stage: str) -> None:
    """--skip <stage> must drop exactly that stage and keep all the others."""
    proc = tier_c("--skip", stage, "--dry-run")
    assert proc.returncode == 0, (
        f"--skip {stage} exited {proc.returncode}.\nstderr: {proc.stderr}")
    assert plan_of(proc) == [s for s in STAGES if s != stage]


def test_only_accepts_a_comma_separated_subset() -> None:
    """The documented form (tier-c.sh:9) is comma-separated, and order follows the TABLE, not
    the argument, so a plan cannot be reordered into running corpus before tier-b."""
    proc = tier_c("--only", "corpus,jsapi", "--dry-run")
    assert proc.returncode == 0, proc.stderr
    assert plan_of(proc) == ["jsapi", "corpus"]


def test_only_and_skip_are_validated_separately_not_concatenated() -> None:
    """--only jsapi --skip gui must not ask about a stage called 'jsapigui'.

    The replaced code split "$ONLY$SKIP" as one string, which glues the last name of one list to
    the first of the other. It was invisible while EVERY name was rejected anyway.
    """
    proc = tier_c("--only", "jsapi", "--skip", "gui", "--dry-run")
    assert proc.returncode == 0, proc.stderr
    assert plan_of(proc) == ["jsapi"]
    assert "jsapigui" not in proc.stderr


def test_the_equals_form_is_accepted_too() -> None:
    """--only=<stage> is a separate arm of the argument parser (tier-c.sh:166)."""
    proc = tier_c("--only=asan", "--dry-run")
    assert proc.returncode == 0, proc.stderr
    assert plan_of(proc) == ["asan"]


# --------------------------------------------- the invalid-name direction (the falsifiability)


def test_only_still_rejects_an_unknown_stage() -> None:
    """THE LOAD-BEARING HALF. A validator that accepts everything passes every test above.

    An unknown stage must be a FATAL usage error (rc=2 per the repo convention: 2 = refused),
    never an empty selection reported as a pass -- "tier-c: GREEN, 0 stages" is the purest
    vacuous green this tier exists to prevent.
    """
    proc = tier_c("--only", "nosuchstage", "--dry-run")
    assert proc.returncode != 0, (
        "--only nosuchstage exited 0; a typo in a selection must not produce a vacuous green.\n"
        f"stdout: {proc.stdout}")
    assert proc.returncode == 2, f"expected the usage-error code 2, got {proc.returncode}"
    assert "no such stage 'nosuchstage'" in proc.stderr
    assert "tier-c: plan" not in proc.stdout


def test_skip_still_rejects_an_unknown_stage() -> None:
    """A typo'd --skip must not silently run the FULL tier while the caller believes a stage was
    excluded -- the failure mode there is a surprise 13-minute corpus run, not a vacuous pass."""
    proc = tier_c("--skip", "nosuchstage", "--dry-run")
    assert proc.returncode == 2, (
        f"--skip nosuchstage exited {proc.returncode}, not 2.\nstdout: {proc.stdout}")
    assert "no such stage 'nosuchstage'" in proc.stderr


@pytest.mark.parametrize("bogus", [
    "jsap",       # a prefix of a real stage
    "jsapix",     # a real stage with a suffix
    "JSAPI",      # wrong case: matching must be exact, not case-folded
    "js api",     # whitespace
    "^jsapi$",    # a regex that a pattern-match implementation would accept for jsapi
    "jsap*",      # a glob that a case-pattern implementation would accept for jsapi
    "jsapi asan"  # two names space-separated instead of comma-separated
])
def test_near_miss_names_are_rejected_exactly(bogus: str) -> None:
    """The match must be EXACT. `grep -qx` was exact; a careless replacement with a substring or
    pattern test would accept '.*' or 'jsap' and quietly select the wrong stages."""
    proc = tier_c("--only", bogus, "--dry-run")
    assert proc.returncode != 0, (
        f"--only {bogus!r} was accepted; stage matching must be exact.\nstdout: {proc.stdout}")
    assert "no such stage" in proc.stderr


def test_a_valid_and_an_invalid_name_together_are_rejected() -> None:
    """One good name must not launder a bad one: the bad name is still named in the error."""
    proc = tier_c("--only", "jsapi,nosuchstage", "--dry-run")
    assert proc.returncode == 2, f"exited {proc.returncode}\nstdout: {proc.stdout}"
    assert "no such stage 'nosuchstage'" in proc.stderr


def test_an_empty_selection_is_fatal_not_an_empty_green() -> None:
    """Skipping every stage is individually legal at each name but collectively vacuous."""
    proc = tier_c("--skip", ",".join(STAGES), "--dry-run")
    assert proc.returncode == 2, f"exited {proc.returncode}\nstdout: {proc.stdout}"
    assert "EMPTY" in proc.stderr


# ------------------------------------------------------------------------------- the table tie


def test_every_declared_stage_is_covered_here() -> None:
    """This file's STAGES list must equal tier-c.sh's table, or the parametrised tests above
    silently stop covering a stage that was added (or keep testing one that was deleted)."""
    text = TIER_C.read_text(encoding="utf-8")
    m = re.search(r'^STAGES="(.*?)"\s*$', text, re.M | re.S)
    assert m, "cannot find the STAGES table in tier-c.sh"
    declared = [ln.split("\\t")[0].strip() for ln in m.group(1).split("\n") if ln.strip()]
    assert declared == STAGES, (
        f"tier-c.sh declares {declared} but this test file covers {STAGES}")


def test_the_selection_path_contains_no_grep_pipeline() -> None:
    """The structural half of the fix, pinned so the defect class cannot come back.

    A `producer | grep -q` under pipefail is the shape that caused this (fleet learning oo-j4u).
    Patching around it with `|| true` would also swallow real failures, so the selection code
    must contain NO pipeline at all -- the stage names live in an array and lookups loop over it.
    """
    text = TIER_C.read_text(encoding="utf-8")
    start = text.index("STAGE_NAMES=()")
    end = text.index("if [ \"$DRY\" = 1 ]", start)
    region = text[start:end]
    code = [ln for ln in region.split("\n")
            if ln.strip() and not ln.lstrip().startswith("#")]
    offenders = [ln for ln in code if re.search(r"\|\s*grep\b", ln)]
    assert not offenders, (
        "the --only/--skip selection path pipes into grep again; under `set -o pipefail` a "
        f"`grep -q` that exits early SIGPIPEs its producer and rc=141 reads as no-match: "
        f"{offenders}")
    assert "|| true" not in region, (
        "a `|| true` in the selection path would hide real failures as well as the SIGPIPE; "
        "the fix must be structural (no pipeline), not a masked exit status")
