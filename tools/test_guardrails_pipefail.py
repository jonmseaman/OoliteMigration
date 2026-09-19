#!/usr/bin/env python3
"""The `producer | grep -q PATTERN` trap, pinned for the tools/ tree (bead oo-mxgy).

THE DEFECT CLASS
----------------
Under `set -o pipefail`, `producer | grep -q PATTERN` inverts its own meaning.
`grep -q` exits the instant it matches; that closes the pipe; a producer still
writing when it happens dies on SIGPIPE; pipefail then reports the pipeline as
141.  So a SUCCESSFUL match is reported as a FAILURE.

Bead oo-3uf8 lost the whole of tier-c.sh's `--only`/`--skip` validator to this:
`all_stage_names | grep -qx "$want"` rejected every valid stage name.  Its fix
was to delete the pipeline (array + `case` loop), never `|| true`, which would
have swallowed genuine failures alongside the phantom one.

WHY THESE ARE STRUCTURAL TESTS AND NOT A RUNTIME REPRO
------------------------------------------------------
The bug DOES NOT REPRODUCE at small scale.  A short producer (`printf 'a\\nb\\n'`)
fits entirely in the 64 KB pipe buffer, finishes writing before grep exits, and
is never signalled -- so the pipeline returns 0 with AND without pipefail.  Both
the fleet orchestrator and oo-3uf8's own worker wrote exactly such a repro, got
a green, and it meant nothing.  Whether a given site fires depends on output
volume, on how slow the producer is, and on scheduling; a site that happens not
to fire today fires the day its producer grows.

A timing-dependent test would therefore be a flaky test that proves nothing.
What CAN be asserted deterministically is the thing that actually matters: the
shape is absent from the files that run with pipefail on.  These tests are the
regression guard the bead is for -- they go RED the day someone reintroduces the
idiom into guardrails.sh, and they go RED the day someone adds `set -o pipefail`
to a file that still carries the idiom.

test_guardrails_sets_pipefail is the anti-vacuity partner of the other two: if
guardrails.sh ever loses `set -o pipefail`, the no-idiom assertions still pass
but they no longer protect anything, so the loss must itself be a failure.

Run:  python3 -m pytest tools/test_guardrails_pipefail.py -q
"""
from __future__ import annotations

import re
from pathlib import Path

import pytest

TOOLS = Path(__file__).resolve().parent
REPO = TOOLS.parent

# `foo | grep -q...`, with any short-option bundle containing q (-q, -qE, -qxF, ...).
# Anchored on a real pipe so `grep -q` reading a file or a here-string -- which cannot
# SIGPIPE anything -- is correctly NOT matched. `(?<!\|)\|(?!\|)` excludes the `||` operator:
# `cmd || grep -qvE pat FILE` is a logical OR feeding grep nothing, not a pipeline.
PIPED_GREP_Q = re.compile(
    r"(?<!\|)\|(?!\|)\s*grep\s+(?:--quiet\b|--silent\b|-[A-Za-z]*q[A-Za-z]*\b)"
)

# `set -o pipefail`, `set -euo pipefail`, `set -eo pipefail`, ...
SETS_PIPEFAIL = re.compile(r"^\s*set\s+-[A-Za-z]*o?[A-Za-z]*\s*(?:-o\s+)?pipefail\b", re.M)


def _code_lines(path: Path):
    """(1-based lineno, text) for lines that are not whole-line shell comments.

    Whole-line comments are excluded deliberately: several tools/ scripts carry a
    comment EXPLAINING this trap (tools/check-enumeration-shuffle.sh:144 is the
    prior art, and guardrails.sh's own header now does too), and a guard that is
    failed by its own documentation is the shape bead oo-j4u recorded as a
    separate defect.  Scan code, not prose.
    """
    out = []
    for i, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        if line.lstrip().startswith("#"):
            continue
        out.append((i, line))
    return out


def _sets_pipefail(path: Path) -> bool:
    text = path.read_text(encoding="utf-8", errors="replace")
    body = "\n".join(l for l in text.splitlines() if not l.lstrip().startswith("#"))
    return bool(SETS_PIPEFAIL.search(body))


def test_guardrails_sets_pipefail():
    """guardrails.sh must run with pipefail, or the other two tests guard nothing.

    Without pipefail a pipeline reports only its LAST command's status, so a git
    or awk that dies mid-pipe is invisible and the guard reports OK on a change
    it never read -- a vacuous green in the one script whose job is to prevent
    vacuous greens.
    """
    assert _sets_pipefail(REPO / "tools" / "guardrails.sh"), (
        "tools/guardrails.sh no longer sets pipefail. Either restore it, or this whole "
        "test file is a no-op: the '| grep -q' assertions only bite under pipefail."
    )


def test_guardrails_has_no_piped_grep_q():
    """The bead's core assertion: the repo's main guard carries none of the idiom.

    guardrails.sh had four instances (is_exempt, is_pending_prefix,
    approval_on_record and -- the worst -- `all_paths | grep -qx "$APPROVALS"`,
    the self-approval check, whose producer is an awk pipeline over the entire
    change).  Under pipefail that last one would have returned 141 on a match, so
    `&& self_approved=1` would never have fired and a change that approves its
    own golden re-bless would have walked straight past the guard.
    """
    hits = [
        (n, t.strip())
        for n, t in _code_lines(REPO / "tools" / "guardrails.sh")
        if PIPED_GREP_Q.search(t)
    ]
    assert not hits, (
        "tools/guardrails.sh sets pipefail and has reacquired the "
        "`producer | grep -q` idiom, which reports a SUCCESSFUL match as exit 141:\n"
        + "\n".join(f"  guardrails.sh:{n}: {t}" for n, t in hits)
        + "\nRemove the pipeline (shell loop with `case`, a here-string, or capture the "
          "producer into a variable). Do NOT add `|| true`: it swallows real failures too."
    )


# --------------------------------------------------------------- the repo-wide ratchet
#
# Sites that still carry the idiom while setting pipefail, audited one by one by bead oo-mxgy.
# The number is the COUNT of surviving instances in that file, so the entry is a RATCHET: adding
# one more fails, and removing one fails too (stale allowances rot silently otherwise, and a
# stale allowance is how a guard quietly stops guarding).
#
# EVERY ENTRY HERE IS "SHAPE PRESENT, NOT REPRODUCED", NOT "PROVEN SAFE".  In each the producer
# is a bash builtin `printf` replaying an in-memory variable, so it normally completes inside the
# 64 KB pipe buffer before grep -q exits and is never signalled -- but that is a statement about
# today's data volume, not a guarantee: any of these fires the day its variable exceeds the pipe
# buffer.  They are left alone because they belong to other beads' files and a drive-by rewrite of
# a gate script is worse than a documented, ratcheted allowance.
KNOWN_SITES = {
    # printf of a captured stdout; each match is against script output of a few KB.
    "tools/merge-queue-acceptance.sh": 13,
    "tools/merge-queue-mutants.sh": 2,
    "tools/tier-b-guardrails-proof.sh": 8,
    "tools/tier-b-mutants.sh": 3,
    "tools/tier-c-mutants.sh": 1,
    "tools/oo-jou1-gate.sh": 1,
    # printf of a single short URL string.
    "tools/merge-queue.sh": 2,
    # Was 2. Bead oo-3uf8 LANDED on main as 7a80d9a and removed its --only/--skip validator
    # (`all_stage_names | grep -qx`) -- the one instance in this class PROVEN to break in
    # production. Do not go looking for it; it no longer exists. The single survivor is
    # :545, `printf '%s\n' "$symtest" | grep -qE ...`: a printf of one short variable
    # completes before grep can exit, so the producer is never mid-write and no 141 is
    # possible. This entry stays at 1 so the count cannot grow back unnoticed.
    "tools/tier-c.sh": 1,
}


@pytest.mark.parametrize(
    "script",
    sorted(p.relative_to(REPO).as_posix() for p in (REPO / "tools").rglob("*.sh")),
)
def test_no_new_piped_grep_q_in_any_pipefail_script(script):
    """Repo-wide ratchet: no NEW `| grep -q` in any tools/ script that sets pipefail.

    Parametrised per file so a new offender names itself instead of hiding inside a
    single aggregate assertion, and so a newly added .sh comes under the guard the
    moment it sets pipefail.
    """
    path = REPO / script
    allowed = KNOWN_SITES.get(script, 0)
    if not _sets_pipefail(path):
        assert allowed == 0, (
            f"{script} no longer sets pipefail but is still listed in KNOWN_SITES; "
            f"delete its entry so the allowance cannot rot into a blanket exemption."
        )
        pytest.skip(f"{script} does not set pipefail; the idiom cannot fire there today")
    hits = [(n, t.strip()) for n, t in _code_lines(path) if PIPED_GREP_Q.search(t)]
    listing = "\n".join(f"  {script}:{n}: {t}" for n, t in hits) or "  (none)"
    assert len(hits) == allowed, (
        f"{script} sets pipefail and has {len(hits)} `producer | grep -q` site(s), "
        f"but {allowed} are recorded in KNOWN_SITES. Under pipefail that idiom reports a "
        f"SUCCESSFUL match as exit 141 whenever the producer is still writing.\n"
        f"{listing}\n"
        f"If you ADDED one: remove the pipeline instead (shell loop with `case`, a "
        f"here-string, or capture the producer into a variable first). Never `|| true` -- "
        f"it swallows genuine failures along with the phantom one.\n"
        f"If you REMOVED one: lower the count in KNOWN_SITES, or delete the entry."
    )


def test_the_detector_actually_detects():
    """Anti-vacuity: a regex that matched nothing would pass every test above.

    Positive controls are the real shapes found in this tree; negative controls
    are the forms that are SAFE and must not be flagged -- `grep -q` reading a
    file or a here-string has no producer to signal, and a non-q grep does not
    exit early.
    """
    must_match = [
        'all_paths | grep -qx "$APPROVALS" && self_approved=1',
        'all_stage_names | grep -qx "$want"',
        "awk '/^export:/{f=1}' cfg | grep -qE '^auto: false'",
        "ccache --show-config 2>/dev/null | grep -qE \"^x\"",
        'printf \'%s\' "$SCAN_EXEMPT" | grep -q "^$1|"',
        "printf '%s\\n' $ARMS | grep -qx -- \"$ONLY\"",
        'cmd | grep --quiet foo',
    ]
    must_not_match = [
        'grep -qE "$CODE_RE" <<< "$1"',          # here-string: no producer process
        'grep -qxF "$1" "$APPROVALS"',            # reads a file
        'norm_change | awk -F"$US" \'{print}\'',  # no grep at all
        "git ls-files -- \"$p\" | grep -c .",     # -c consumes all input, never early-exits
        "grep -v '^$' <<< \"$x\" | sort",         # non-q grep
        "test -f x || grep -qvE $'\\t(yes|no)$' \"$CLASS\"",  # `||`, not a pipe
    ]
    for s in must_match:
        assert PIPED_GREP_Q.search(s), f"detector missed a real instance: {s}"
    for s in must_not_match:
        assert not PIPED_GREP_Q.search(s), f"detector false-positived on a safe form: {s}"


# ------------------------------------------------------------------- the latent set
#
# Files that carry the idiom but do NOT set pipefail today, so it cannot fire in them.
# These are the DANGEROUS ones and the reason this bead exists: `set -o pipefail` is an
# obviously-correct hardening somebody will apply one day, and applying it to one of these
# breaks the file instantly and silently.
#
# They are pinned rather than converted. tools/check-file-modes.sh's two sites are inside
# line_is_call_site(), which is the single source of truth for the call-site grammar and is
# shared with tools/check-file-modes-probe.sh; rewriting that grammar to dodge a bug that
# cannot fire today is a large, risky change to somebody else's gate for no behavioural gain.
# The pin is worth more than the conversion: a conversion can be reverted silently, whereas
# test_no_new_piped_grep_q_in_any_pipefail_script goes RED the moment one of these acquires
# pipefail while the idiom is still present (the file is absent from KNOWN_SITES, so its
# allowance is 0 and every surviving hit is a failure).
#
# This test asserts the premise that makes that pin meaningful. If a file drops off this list,
# read WHY before updating it: either it was converted (good, delete the entry) or it gained
# pipefail (in which case the ratchet test above is already red and must be fixed, not listed).
LATENT_SET = {
    "tools/check-file-modes.sh": 3,
    "tools/check-file-modes-probe.sh": 1,
}


@pytest.mark.parametrize("script,count", sorted(LATENT_SET.items()))
def test_latent_sites_still_lack_pipefail(script, count):
    """A latent `| grep -q` site is safe ONLY while its file has no pipefail."""
    path = REPO / script
    assert path.exists(), f"{script} is gone; delete its LATENT_SET entry"
    hits = [(n, t.strip()) for n, t in _code_lines(path) if PIPED_GREP_Q.search(t)]
    assert not _sets_pipefail(path), (
        f"{script} has acquired `set -o pipefail` while still carrying "
        f"{len(hits)} `producer | grep -q` site(s):\n"
        + "\n".join(f"  {script}:{n}: {t}" for n, t in hits)
        + "\nThat combination inverts every one of them: grep -q exits on the first match, "
          "SIGPIPEs the producer, and pipefail reports 141, so a SUCCESSFUL match reads as a "
          "FAILURE. Convert the sites first (shell loop with `case`, a here-string, or capture "
          "the producer into a variable), then move the file into KNOWN_SITES or drop it from "
          "both lists. Do NOT reach for `|| true`."
    )
    assert len(hits) == count, (
        f"{script} now has {len(hits)} `| grep -q` site(s), not the {count} recorded in "
        f"LATENT_SET. Update the count if you converted one; if you ADDED one, remove the "
        f"pipeline instead -- this file is one `set -o pipefail` away from breaking."
    )
