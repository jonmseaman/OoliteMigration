#!/usr/bin/env python3
"""Load one expansion on the built game and judge the resulting Latest.log (bead oo-het).

THE VACUITY PROBLEM THIS FILE IS ABOUT
--------------------------------------
"assert there are no ERROR lines in Latest.log" is trivially TRUE when the game
never really ran.  This is not hypothetical here; it was MEASURED on this host,
and the measurement is committed as a fixture:

    tools/oxp-corpus/fixtures/dead-initgl-Latest.log

That file is a REAL log from a REAL launch on this machine.  The game started
with /ucrt64/bin on PATH, wrote its version banner, recorded its own command
line at [process.args] (including -load), negotiated an 8-bpcc 24-bit-depth GL
buffer, printed the V-Sync warning - and then DIED with exit 87
(ERROR_INVALID_PARAMETER), 1476 bytes, 19 lines, having loaded no world and
parsed no expansion whatsoever.

IT CONTAINS ZERO LINES MATCHING ERROR.  A naive "grep -c ERROR == 0" check
calls that launch a PASS.  Everything below exists so that it cannot.

Note what this means for marker choice: the banner, the CPU line, the build
options line and [process.args] are ALL PRESENT in the dead log, so none of them
can serve as evidence of loading.  The marker must come from AFTER world and
expansion load.

EXIT 87 IS THE BARE-LAUNCH BASELINE, NOT A DLL BUG.  A bare
`oolite.exe --no-splash` (even with a -load argument) dies at 87 within a
second or two on this box.  It is NOT 0xC0000135/STATUS_DLL_NOT_FOUND - that is
a different failure, caused by /ucrt64/bin being absent from PATH, and it writes
no log at all.  What makes the launch work is the software-GL environment the
component/golden harness sets (upstream/oolite/tests/component/console.py
_env): LIBGL_ALWAYS_SOFTWARE=1, GALLIUM_DRIVER=llvmpipe, SDL_AUDIODRIVER=dummy,
ALSOFT_DRIVERS=null.  With those, `-load Resources/Scenarios/oolite-standard.
oolite-save` runs to [startup.complete] and the process EXITS ON ITS OWN with
rc=0 in ~18s, which is what makes a per-expansion load check affordable: no
console socket, no port, no debugConfig.plist, no synthetic input.

THE FIVE POSITIVE ASSERTIONS, in order.  Nothing concludes anything from the
absence of ERROR until all five hold:

  P1 LAUNCH   the process ran and did not die with a Windows loader status; a
              death before any log is reported as LAUNCH, never as PASS.
  P2 LOG      the log exists in THIS RUN'S OWN private OO_LOGSDIR (so it cannot
              be a stale file from another run), carries the "Opening log for
              Oolite version" banner, and is >= MIN_LOG_LINES lines - a bound
              set ABOVE the committed dead-log fixture's length on purpose.
  P3 SHIPDATA the log contains "[shipData.load.begin]: Loading ship data." -
              the first line the game emits from the DATA layer, after search
              paths are resolved.  Absent from the dead fixture.
  P4 STARTUP  the log contains "[startup.complete]" - emitted by Universe once
              loading has finished.  Absent from the dead fixture.  NOTE: the
              sentinel (P4b) defers its quit behind a short timer precisely so
              that this line still gets logged; an early-quitting sentinel
              destroyed this evidence and the two assertions were mutually
              exclusive.  Both are kept because they prove different things -
              P4 is the GAME saying it finished booting, P4b is THIS RUN saying
              it finished on its own terms.
  P4b SENTINEL the log contains this run's OWN end-of-run marker,
              "[oo-het.sentinel]: OO-HET-SENTINEL-OK", emitted from a
              startUpComplete handler in tools/oxp-corpus/sentinel, which is
              staged next to every expansion under test.  THIS ONE GUARDS
              AGAINST A STRANGER ENDING THE RUN.  Measured on this machine: a
              bare game dials out to the default debug-console port 8563, lands
              in a SIBLING worker's component-test listener
              ("OoliteComponentTests"), and is quit() by it 4.7s after
              startup - rc=0, clean log, nothing loaded of ours.  rc=0 plus "no
              ERROR lines" is therefore NOT evidence the run completed.  Only a
              marker the run itself caused is.  (The sentinel also ships a
              Config/debugConfig.plist steering the dial-out to a dead port, so
              the raid is prevented as well as detected.)
  P5 LOADED   the expansion's own staged filename appears inside the
              "[searchPaths.dumpAll]: Resource paths:" block.  THIS IS THE ONE
              THAT MATTERS.  That block is printed by ResourceManager +logPaths
              from sSearchPaths, and an OXP/OXZ reaches sSearchPaths only via
              checkPotentialPath (ResourceManager.m:613-668), i.e. only after
              its manifest.plist has been read and its identifier, version,
              title and required_oolite_version validated.  A file that merely
              sits in the AddOns directory does NOT appear there - verified: an
              OXZ whose manifest cannot be read logs [oxp.noManifest] and is
              absent from the block.  So P5 is precisely "the game parsed this
              expansion and accepted it".

Only then is the ERROR scan meaningful, and only then is its verdict reported.

Usage (normally driven by tools/corpus.sh):
    python3 tools/oxp_load_check.py --app-dir DIR --oxp PATH [--oxp PATH ...]
                                    [--work DIR] [--timeout S] [--json OUT]
    python3 tools/oxp_load_check.py --judge-log FILE --expect-staged NAME
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

#: A Latest.log shorter than this did not get far enough for an ERROR scan to
#: mean anything.  The committed dead-initgl fixture is 19 lines; a real load is
#: 80+.  The bound sits between them, nearer the floor, so it rejects the known
#: vacuous shape without being tuned to one machine's exact line count.
MIN_LOG_LINES = 40

#: Windows loader status: the process died before its entry point (missing DLL).
STATUS_DLL_NOT_FOUND = 3221225781
#: ERROR_INVALID_PARAMETER: the measured bare-launch baseline on this host.
BARE_LAUNCH_EXIT = 87

#: The scenario save.  -load starts a REAL game; without it the game sits on the
#: intro screen and never loads a world (console.py says so at its `load_save`).
SCENARIO_SAVE = "Resources/Scenarios/oolite-standard.oolite-save"

#: The witness OXP staged alongside every expansion under test (see P4b).
SENTINEL_OXP = (Path(__file__).resolve().parent / "oxp-corpus" / "sentinel"
                / "oo-het-sentinel.oxp")

BANNER_RE = re.compile(r"^Opening log for Oolite version ", re.M)
SHIPDATA_RE = re.compile(r"\[shipData\.load\.begin\]")
STARTUP_RE = re.compile(r"\[startup\.complete\]")
SEARCHPATHS_RE = re.compile(r"\[searchPaths\.dumpAll\]: Resource paths:")
#: This run's own end-of-run marker. Split in source for the same reason the
#: sentinel script splits it: a literal here that also appeared in the staged
#: script text could be matched from the wrong place.
SENTINEL_MARKER = "OO-HET-" + "SENTINEL-OK"
SENTINEL_RE = re.compile(r"\[oo-het\.sentinel\]: " + re.escape(SENTINEL_MARKER))
#: The sibling-harness raid this bead measured, reported by name when it happens.
RAIDED_RE = re.compile(r"\[debugTCP\.connected\]: Connected to debug console \"(.*?)\"")

# --------------------------------------------------------------------- errors
#
# WHAT COUNTS AS AN "ERROR LINE", AND WHY IT IS NOT JUST grep ERROR.
#
# The bead says "no ERROR lines in Latest.log".  Taken as a literal substring
# search that check is ALMOST ENTIRELY VACUOUS on this game, and this was
# measured, not guessed.  The deliberately-broken fixture in
# tools/oxp-corpus/broken - a malformed shipdata.plist plus a world script
# calling an undefined global - produces these two lines:
#
#   [plist.parse.failed]: Failed to parse .../oo-het-broken.oxp/Config/
#       shipdata.plist as a property list.
#   [script.javaScript.exception.notDefined]: ***** JavaScript exception
#       (oo-het-broken 1.0): ReferenceError: ooHetThisMethodDoesNotExist is
#       not defined
#
# NEITHER CONTAINS THE WORD "ERROR".  A literal grep passes that expansion, and
# the tier check would be green on an expansion that fails to parse its own ship
# data.  So "ERROR line" is interpreted as "a line Oolite's own logging emits on
# an error", identified three ways, all read off the product's source:
#
#   * OOLOG_ERROR_PREFIX (OOLogging.h:109) - OOLogERR renders "***** ERROR: ".
#     Also caught by the bare-token rule below.
#   * The "*****" attention prefix Oolite uses for errors and exceptions
#     (OOLogging.h:109-113, OOLogging.m:488-503).
#   * The log CHANNEL: logcontrol.plist routes error classes through names
#     ending .error / .failed, and JS exceptions through
#     script.javaScript.exception.*.  A channel is machine-readable and does not
#     depend on the wording of any one message.
#
# ONE FAMILY IS EXCLUDED, DELIBERATELY AND NARROWLY: debugTCP.*.  Those lines
# ("Failed to connect to debug console at address 127.0.0.1:...") are caused by
# THIS HARNESS, not by the expansion under test - the sentinel's
# debugConfig.plist points the game's debug-console dial-out at a dead port on
# purpose, so that a sibling worker's listener cannot reach in and quit the run
# (see P4b).  Counting our own deliberate refusal to connect as an expansion
# error would make every check red for a reason having nothing to do with any
# expansion.  The exclusion is limited to that one channel prefix; nothing else
# is filtered, and the exclusion is asserted in the test suite so it cannot
# quietly widen.
ERROR_TOKEN_RE = re.compile(r"\bERROR\b")
ERROR_STARS_RE = re.compile(r"\*\*\*\*\*")
ERROR_CHANNEL_RE = re.compile(r"^\d\d:\d\d:\d\d\.\d+ \[([^\]]+)\]")
ERROR_CHANNEL_NAME_RE = re.compile(r"(\.error|\.failed|\.exception)(\.|$|:)", re.I)
#: the one excluded family - see the comment block above
BENIGN_CHANNEL_PREFIX = "debugTCP."


def channel_of(line: str) -> str | None:
    m = ERROR_CHANNEL_RE.match(line.strip())
    return m.group(1) if m else None


def is_error_line(line: str) -> bool:
    """True if `line` is an error Oolite logged about the content under test."""
    chan = channel_of(line)
    if chan and chan.startswith(BENIGN_CHANNEL_PREFIX):
        return False
    if chan and ERROR_CHANNEL_NAME_RE.search(chan):
        return True
    if ERROR_TOKEN_RE.search(line) or ERROR_STARS_RE.search(line):
        # A continuation line of a benign channel carries no [channel] prefix of
        # its own; attribute it to the channel it continues rather than judging
        # it alone (an early-return here is how a log filter leaks what it was
        # written to drop).
        return True
    return False


class Verdict:
    LAUNCH = "LAUNCH"        # the game did not run / died before writing a log
    LOG = "LOG"              # no usable log was produced
    NOSHIPDATA = "NOSHIPDATA"  # never reached the data layer
    STARTUP = "STARTUP"      # ran but never finished loading
    NOSENTINEL = "NOSENTINEL"  # the run did not end under our own control
    NOTLOADED = "NOTLOADED"  # the expansion was not accepted into the search paths
    ERRORS = "ERRORS"        # loaded fine, but the log has ERROR lines
    PASS = "PASS"
    # --- added by bead oo-kcrw, for dependency-aware GROUP loading -----------
    #
    # Each of these is a DISTINCT failure with a distinct owner and a distinct
    # response, and collapsing any of them into ERRORS/NOTLOADED would destroy
    # the per-expansion attribution that is this instrument's whole value.
    UNSATISFIABLE = "UNSATIS"    # a declared requirement is not in the corpus at
                                 # all, so the expansion never got a chance to
                                 # load. NOT a load failure; no launch happens.
    DEPNOTLOADED = "DEPNOTLD"    # the PRIMARY loaded but a DEPENDENCY did not:
                                 # the group is not a valid test of the primary.
    DEPERRORS = "DEPERR"         # the primary loaded cleanly; the error lines
                                 # belong to a named DEPENDENCY. Still a failure,
                                 # but reported against the dependency.
    NOMANIFEST = "NOMANIF"       # the expansion LOADED and its ONLY error is the
                                 # standards complaint that it ships no
                                 # manifest.plist - a legacy in-tree fixture that
                                 # predates the manifest format. Non-fatal, and
                                 # argued in full at NOMANIFEST_RE below.
    # --- added by bead oo-1gc.7 (proposed ADR-0047) ---------------------------
    KNOWN = "KNOWN"              # the group's errors are EXACTLY the reviewed lines
                                 # in known-content-failures.json, on the pinned
                                 # member bytes. Non-fatal; lines still printed.
    KNOWNCHANGED = "KNOWNCHG"    # the group has a known-failure entry but its
                                 # errors (or its bytes) no longer match it: a new,
                                 # changed or vanished line. Fatal.


#: bead oo-1gc.7, proposed ADR-0047. The reviewed list of Tier-1 groups whose
#: errors are diagnosed CONTENT defects, identical on both engines. See
#: apply_known_failure() for the exact rule; it is a re-label of an exact,
#: pinned match, never a filter.
KNOWN_FAILURES_JSON = (Path(__file__).resolve().parent / "oxp-corpus"
                       / "known-content-failures.json")
TIMESTAMP_RE = re.compile(r"^\s*\d\d:\d\d:\d\d\.\d+ ")
#: The group verdicts that do not fail the tier. Everything else does.
GROUP_OK_STATES = (Verdict.PASS, Verdict.NOMANIFEST, Verdict.KNOWN)


def normalise_error_line(line: str) -> str:
    """An error line without its leading timestamp - the only volatile part."""
    return TIMESTAMP_RE.sub("", line.rstrip())


def load_known_failures(path: Path = KNOWN_FAILURES_JSON) -> dict:
    """{group name: entry}. A malformed file is a harness error (ValueError), never
    an empty list: an unreadable review list must not quietly accept nothing, and
    must not quietly accept everything either."""
    if not Path(path).exists():
        return {}
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    if data.get("schema") != 1:
        raise ValueError("%s: unknown schema %r" % (path, data.get("schema")))
    out = {}
    for e in data.get("entries", []):
        g = e.get("group")
        for key in ("members_sha256", "beads", "diagnosis", "expected_errors"):
            if not e.get(key):
                raise ValueError("%s: entry %r has no %s" % (path, g, key))
        if not g or g in out:
            raise ValueError("%s: missing or duplicate group %r" % (path, g))
        if any(normalise_error_line(l) != l for l in e["expected_errors"]):
            raise ValueError("%s: entry %r has an expected line with a timestamp" % (path, g))
        out[g] = e
    return out


def member_sha256s(members) -> dict:
    """sha256 of each staged member's bytes (files only; in-tree dirs have none)."""
    import hashlib
    out = {}
    for m in members:
        p = Path(m["path"])
        if p.is_file():
            out[m["identifier"]] = hashlib.sha256(p.read_bytes()).hexdigest()
    return out


def apply_known_failure(name: str, verdict: str, detail: str, all_errors, shas: dict,
                        known: dict) -> tuple:
    """Re-label a group's verdict against the reviewed known-content-failures list.

    Returns (verdict, detail). Only a group WITH an entry is ever touched, and then:
      * the members' bytes must equal the entry's pinned sha256s, else KNOWNCHG -
        the diagnosis was made on other content;
      * the run must have reached the error scan (ERRORS, DEPERRORS or PASS); any
        earlier failure (NOTLOADED, STARTUP, ...) is returned unchanged, still red;
      * the timestamp-stripped error lines must equal expected_errors EXACTLY, as a
        multiset: one extra, one missing or one altered line is KNOWNCHG. Zero
        errors is also KNOWNCHG - the recorded diagnosis no longer holds, and a
        silent change in the loader is exactly what this tier exists to notice.
    Only an exact match becomes KNOWN. The lines stay in the result and are printed.
    """
    from collections import Counter
    entry = known.get(name)
    if entry is None:
        return verdict, detail
    if verdict not in (Verdict.ERRORS, Verdict.DEPERRORS, Verdict.PASS):
        return verdict, detail
    if shas != entry["members_sha256"]:
        return (Verdict.KNOWNCHANGED,
                "%s has a known-content-failures.json entry (%s) but the staged member "
                "bytes differ from the pinned sha256s (staged %s, pinned %s), so the "
                "recorded diagnosis does not apply - re-diagnose. Underlying: %s %s"
                % (name, ", ".join(entry["beads"]), shas, entry["members_sha256"],
                   verdict, detail))
    got = Counter(normalise_error_line(l) for l in all_errors)
    want = Counter(entry["expected_errors"])
    if got == want:
        return (Verdict.KNOWN,
                "%s: its %d error line(s) EXACTLY match the reviewed known content failure "
                "(%s; tools/oxp-corpus/known-content-failures.json): %s"
                % (name, sum(got.values()), ", ".join(entry["beads"]),
                   entry["diagnosis"].split(". ")[0] + "."))
    extra, missing = got - want, want - got
    return (Verdict.KNOWNCHANGED,
            "%s's errors NO LONGER MATCH its known-content-failures.json entry (%s): "
            "%d unexpected line(s) %s; %d expected line(s) absent %s. A new or changed "
            "error is a new finding; vanished errors mean the loader changed. Either way "
            "the entry needs review."
            % (name, ", ".join(entry["beads"]), sum(extra.values()), sorted(extra),
               sum(missing.values()), sorted(missing)))


#: The exact standards complaint emitted for an expansion with no manifest.plist:
#: OOStandardsError from ResourceManager, rendered as
#:   [oxp-standards.error]: OXP <path> has no manifest.plist
#:
#: WHY THIS GETS ITS OWN NON-FATAL STATE, AND WHY THAT IS NOT A LOOSENED PREDICATE.
#: Five of the six in-tree test-oxps (upstream/oolite-tests/test-oxps) ship no
#: manifest.plist at all; they predate the format. Measured: each produces
#: EXACTLY 2 error lines per run and they are all this one message. The tell that
#: it is a fixture property rather than five independent defects is that five
#: unrelated fixtures produce an identical count of exactly 2.
#:
#: Reporting them as ERRORS - the same state as an expansion whose ship data does
#: not parse - sends the next reader hunting a bug that does not exist, and that
#: is a REPORTING defect. So they get their own state, and it is non-fatal.
#:
#: The classification is narrow by construction and cannot widen into a silencer:
#:   * it requires the expansion to have LOADED first (P5 satisfied) - a rejected
#:     expansion is NOTLOADED and never reaches this branch;
#:   * it requires that EVERY error line in the run match this one message. One
#:     additional error line of any kind and the verdict is ERRORS again, with
#:     the manifest lines still listed;
#:   * the message must NAME a staged member, so an unrelated expansion's missing
#:     manifest cannot be absorbed;
#:   * the lines are still PRINTED, still recorded in the JSON, and still counted.
#:     Nothing is suppressed - only re-labelled, with the count reported.
#: tools/test_oxp_deps.py pins every one of those conditions, and the mutation
#: harness shows the gate go red if the match is widened.
NOMANIFEST_RE = re.compile(r"\bhas no manifest\.plist\s*$")


def _launch_env(logs: Path, addons: Path | None):
    """The environment that actually launches this build headlessly.

    Two separate hazards are handled here, and conflating them wastes hours:

    (a) PATH.  oolite.exe's staged opengl32.dll loads libgallium_wgl.dll, which
        needs libLLVM-*.dll / libSPIRV-Tools.dll / libsystre-0.dll.  Those live
        only in the MSYS2 UCRT64 bin directory and appear in NO static import
        table.  Without it: exit 3221225781 and NO log at all.
    (b) SOFTWARE GL.  Even with PATH correct, a bare launch dies at exit 87
        after [display.initGL] having loaded nothing.  The component harness's
        software-GL variables are what carry it through to a real world load.
    """
    env = os.environ.copy()
    for cand in ("C:/msys64/ucrt64/bin", "/ucrt64/bin",
                 (os.environ.get("MINGW_PREFIX") or "") + "/bin"):
        if cand and os.path.isdir(cand):
            if cand.lower() not in (env.get("PATH") or "").lower():
                env["PATH"] = cand + os.pathsep + env.get("PATH", "")
            break
    env["LIBGL_ALWAYS_SOFTWARE"] = "1"
    env["GALLIUM_DRIVER"] = "llvmpipe"
    env["SDL_AUDIODRIVER"] = "dummy"
    env["ALSOFT_DRIVERS"] = "null"
    env["OO_LOGSDIR"] = str(logs).replace("/", "\\")
    if addons is not None:
        env["OO_ADDITIONALADDONSDIRS"] = str(addons).replace("/", "\\")
    return env


def judge(text: str, staged: str | None, log_label: str, rc=None, timeout=None,
          require_sentinel: bool = True, scan_errors: bool = True) -> tuple:
    """Apply P2-P5 then the ERROR scan to a log's TEXT. Returns (verdict, detail, errors).

    Split out from run_one deliberately so the guard can be exercised offline
    against the committed dead-log fixture with no game launch at all - that is
    what makes the vacuity guard itself testable in a fresh checkout.
    """
    lines = text.splitlines()

    # ---- P2 LOG ----------------------------------------------------------
    if not BANNER_RE.search(text):
        return (Verdict.LOG,
                "%s has no 'Opening log for Oolite version' banner - not an Oolite log"
                % log_label, [])
    if len(lines) < MIN_LOG_LINES:
        return (Verdict.LOG,
                "%s is only %d lines (< %d): the game died early, so an absence of ERROR "
                "lines proves nothing" % (log_label, len(lines), MIN_LOG_LINES), [])

    # ---- P3 SHIPDATA -----------------------------------------------------
    if not SHIPDATA_RE.search(text):
        return (Verdict.NOSHIPDATA,
                "%s never reached [shipData.load.begin]: the game exited before the data "
                "layer ran (exit %s), so no expansion was parsed and an absence of ERROR "
                "lines is vacuous" % (log_label, rc), [])

    # ---- P4 STARTUP ------------------------------------------------------
    if not STARTUP_RE.search(text):
        return (Verdict.STARTUP,
                "%s never reached [startup.complete]%s (exit %s); loading did not finish"
                % (log_label, "" if timeout is None else " within %.0fs" % timeout, rc), [])

    # ---- P4b SENTINEL ----------------------------------------------------
    if require_sentinel and not SENTINEL_RE.search(text):
        raider = RAIDED_RE.search(text)
        extra = ""
        if raider:
            extra = (" The log shows this run was reached by an EXTERNAL debug console named "
                     "%r - a sibling worker's harness, which quits the game. rc=0 and a clean "
                     "log are therefore NOT evidence the run completed."
                     % raider.group(1))
        return (Verdict.NOSENTINEL,
                "%s does not contain this run's own end-of-run marker "
                "[oo-het.sentinel]: %s, so the run did not finish under our control and "
                "an absence of ERROR lines proves nothing.%s"
                % (log_label, SENTINEL_MARKER, extra), [])

    # ---- P5 LOADED -------------------------------------------------------
    if staged is not None:
        entries = searchpath_entries(text)
        if entries is None:
            return (Verdict.NOTLOADED,
                    "%s has no [searchPaths.dumpAll] block - cannot prove the expansion "
                    "was parsed" % log_label, [])
        if not is_loaded(entries, staged):
            return (Verdict.NOTLOADED,
                    "%r is ABSENT from the [searchPaths.dumpAll] Resource paths block in %s "
                    "(block listed %d path(s): %s), so the game never accepted it into "
                    "sSearchPaths - ResourceManager checkPotentialPath rejected it (no/invalid "
                    "manifest.plist, unmet required_oolite_version, or unmet requires_oxps). "
                    "The expansion did NOT load; any absence of ERROR lines is vacuous."
                    % (staged, log_label, len(entries),
                       ", ".join(entry_names(entries))), [])

    # ---- only now is the ERROR scan meaningful ---------------------------
    # Carry the channel across continuation lines: a wrapped message's tail has
    # no [channel] prefix of its own, and judging it alone would let the tail of
    # an excluded message be counted (or the tail of a real error be missed).
    #
    # scan_errors=False is used ONLY by judge_group(), which needs P2-P4b applied
    # unchanged but must run the error scan itself so it can ATTRIBUTE each line
    # to the member that owns it. Returning ERRORS here would collapse "a
    # dependency emitted this" into "the primary failed" - the precise loss of
    # attribution bead oo-kcrw exists to prevent. It never widens what counts as
    # an error: judge_group calls the same error_lines() on the same text.
    if not scan_errors:
        return (Verdict.PASS, "run-level guards P2-P4b passed; error scan deferred to "
                              "the group attributor", [])
    errs = error_lines(text)
    if errs:
        who = staged or "the log"
        return (Verdict.ERRORS,
                "%s FAILED: %d ERROR line(s) attributable to it in %s"
                % (who, len(errs), log_label), errs[:20])

    return (Verdict.PASS,
            "loaded (named in searchPaths.dumpAll), reached shipData.load.begin and "
            "startup.complete, %d log lines, 0 ERROR lines" % len(lines), [])


def searchpath_entries(text: str):
    """The indented path entries of the [searchPaths.dumpAll] block, or None.

    Factored out of judge() by bead oo-kcrw so a GROUP check can ask the same
    question about several staged files from one log without re-parsing it, and
    so the parsing itself is testable offline against a captured log.
    """
    if not SEARCHPATHS_RE.search(text):
        return None
    after = text.split("[searchPaths.dumpAll]: Resource paths:", 1)[1]
    entries = []
    for ln in after.splitlines()[1:]:
        if re.match(r"^\s*\d\d:\d\d:\d\d\.\d+ \[", ln):
            break
        if ln.startswith("    "):
            entries.append(ln.strip().replace("\\", "/"))
    return entries


def entry_names(entries):
    return [e.rsplit("/", 1)[-1] for e in entries]


def is_loaded(entries, staged: str) -> bool:
    """Whether `staged` appears as an ENTRY of the search-path block.

    An entry must EQUAL the staged filename or END WITH "/" + it. Matching the
    bare name against the whole log was a measured false-positive generator: the
    per-run work directory is itself named after the expansion, so the name
    appears in the block as part of the AddOns ROOT path even when the expansion
    was rejected. Five test-oxps reported PASS that way.
    """
    want = staged.replace("\\", "/")
    return any(e == want or e.endswith("/" + want) for e in entries)


def error_lines(text: str):
    """Every error line in `text`, with the benign harness channel excluded.

    Factored out of judge() (bead oo-kcrw) so the group checker can run the SAME
    detector and then attribute the lines it finds, rather than reimplementing
    the scan with a different definition of "error".
    """
    errs = []
    current = None
    for ln in text.splitlines():
        chan = channel_of(ln)
        if chan is not None:
            current = chan
        if current and current.startswith(BENIGN_CHANNEL_PREFIX):
            continue
        if is_error_line(ln):
            errs.append(ln)
    return errs


def judge_group(text: str, members, log_label: str, rc=None, timeout=None,
                require_sentinel: bool = True) -> tuple:
    """Judge a log from a run that staged a PRIMARY plus its dependency closure.

    `members` is the ordered list produced by oxp_deps.tier1_groups()[i]["members"]:
    dicts with staged_as / identifier / title / role, the first being the primary.

    WHY THIS IS NOT JUST judge() IN A LOOP.  Loading a SET changes what a failure
    means, and the whole value of this instrument is per-expansion attribution:

      * if the PRIMARY is absent from the search-path block -> NOTLOADED, as
        before, and the dependencies are named so the reader can see they WERE
        staged (which is what distinguishes "unmet requirement" from "the
        grouping did not work");
      * if the primary loaded but a DEPENDENCY did not -> DEPNOTLOADED naming
        the dependency. The run is not a valid test of the primary and must not
        be green, but the primary is not the culprit;
      * if the log has error lines, they are ATTRIBUTED. An error emitted by a
        dependency is reported as DEPERRORS against that dependency, never as
        "the primary FAILED" - that would send the next reader to audit an
        expansion that is fine;
      * an error line that NO staged expansion claims is reported explicitly as
        unattributed rather than being folded into the primary's tally. An
        unowned error is a finding about the engine or the harness and hiding it
        inside a primary's verdict destroys that signal.

    Returns (verdict, detail, errors, per_member) where per_member maps each
    member's identifier to {"staged_as", "role", "loaded", "errors"}.
    """
    import oxp_deps  # local import: keeps this module importable standalone

    primary = members[0]
    # P2-P4b are properties of the RUN, not of any one expansion, so they are
    # delegated to the existing single-expansion judge with staged=None (which
    # skips its P5) and returned unchanged. Reimplementing them here is how two
    # copies of a guard drift apart.
    v, d, _ = judge(text, None, log_label, rc=rc, timeout=timeout,
                    require_sentinel=require_sentinel, scan_errors=False)
    if v != Verdict.PASS:
        return (v, d, [], {})

    entries = searchpath_entries(text)
    if entries is None:
        return (Verdict.NOTLOADED,
                "%s has no [searchPaths.dumpAll] block - cannot prove any expansion "
                "was parsed" % log_label, [], {})

    per = {}
    for m in members:
        per[m["identifier"]] = {
            "staged_as": m["staged_as"], "role": m["role"],
            "loaded": is_loaded(entries, m["staged_as"]), "errors": [],
        }

    staged_names = ", ".join(m["staged_as"] for m in members[1:]) or "(none)"
    if not per[primary["identifier"]]["loaded"]:
        return (Verdict.NOTLOADED,
                "%r is ABSENT from the [searchPaths.dumpAll] Resource paths block in %s "
                "(block listed %d path(s): %s) EVEN THOUGH its declared requires_oxps "
                "closure was staged alongside it [%s], so the dependency explanation does "
                "NOT account for this one - ResourceManager checkPotentialPath rejected it "
                "for some other reason (no/invalid manifest.plist, unmet "
                "required_oolite_version, or an UNDECLARED requirement). The expansion did "
                "NOT load; any absence of ERROR lines is vacuous."
                % (primary["staged_as"], log_label, len(entries),
                   ", ".join(entry_names(entries)), staged_names), [], per)

    unloaded_deps = [m for m in members[1:] if not per[m["identifier"]]["loaded"]]
    if unloaded_deps:
        return (Verdict.DEPNOTLOADED,
                "%s loaded, but %d of its %d staged DEPENDENC%s did not appear in the "
                "[searchPaths.dumpAll] block: %s. The group is therefore not a valid test "
                "of %s - the dependency is the thing to investigate, not the primary."
                % (primary["staged_as"], len(unloaded_deps), len(members) - 1,
                   "Y" if len(unloaded_deps) == 1 else "IES",
                   ", ".join(m["staged_as"] for m in unloaded_deps),
                   primary["identifier"]), [], per)

    # ---- attribution -----------------------------------------------------
    owners = [{"label": m["identifier"],
               "tokens": oxp_deps.owner_tokens(m, m["staged_as"])} for m in members]
    by_owner = oxp_deps.attribute_errors(error_lines(text), owners)
    for ident, lines in by_owner.items():
        if ident in per:
            per[ident]["errors"] = lines

    prim_errs = by_owner.get(primary["identifier"], [])
    dep_errs = [(m["identifier"], by_owner.get(m["identifier"], []))
                for m in members[1:] if by_owner.get(m["identifier"])]
    unowned = by_owner.get(oxp_deps.UNATTRIBUTED, [])
    all_errs = prim_errs + [l for _, e in dep_errs for l in e] + unowned

    # ---- the legacy-fixture class, decided before ERRORS ------------------
    # Only when EVERY error line in the whole run is the "has no manifest.plist"
    # standards complaint AND every such line was attributed to a staged member.
    # One extra line of any kind, or one unowned manifest complaint, falls
    # through to the normal ERRORS handling below with these lines still listed.
    if all_errs and not unowned and all(NOMANIFEST_RE.search(l) for l in all_errs):
        return (Verdict.NOMANIFEST,
                "%s LOADED (named in searchPaths.dumpAll) and its ONLY %d error line(s) "
                "are the standards complaint that it ships no manifest.plist. That is a "
                "property of this legacy in-tree fixture, which predates the manifest "
                "format - NOT a content defect - so it is reported as its own state "
                "rather than as ERRORS, and the lines are printed below rather than "
                "suppressed. Any additional error of any kind makes this ERRORS again."
                % (primary["staged_as"], len(all_errs)), all_errs[:20], per)

    if prim_errs:
        return (Verdict.ERRORS,
                "%s FAILED: %d ERROR line(s) attributable to IT (of %d in %s; %s)"
                % (primary["staged_as"], len(prim_errs),
                   len(prim_errs) + sum(len(e) for _, e in dep_errs) + len(unowned),
                   log_label,
                   "no dependency errors" if not dep_errs else
                   "dependency errors: " + "; ".join("%s=%d" % (i, len(e)) for i, e in dep_errs)),
                prim_errs[:20], per)
    if dep_errs:
        who = ", ".join("%s (%d)" % (i, len(e)) for i, e in dep_errs)
        return (Verdict.DEPERRORS,
                "%s itself loaded with NO error lines of its own; the %d error line(s) in "
                "this run belong to its DEPENDENC%s %s. This is still a failure, but it is "
                "NOT a failure of %s - investigate the dependency."
                % (primary["staged_as"], sum(len(e) for _, e in dep_errs),
                   "Y" if len(dep_errs) == 1 else "IES", who, primary["identifier"]),
                [l for _, e in dep_errs for l in e][:20], per)
    if unowned:
        chans = sorted({channel_of(l) or "?" for l in unowned})
        return (Verdict.ERRORS,
                "%d ERROR line(s) in %s that NO staged expansion claims (primary %s and %d "
                "dependencies all loaded cleanly; channels: %s). An unowned error is "
                "reported rather than folded into the primary: attribution works by finding "
                "a staged member's filename, identifier or title IN the line, and these "
                "lines contain none of those. Candidate causes, in order of likelihood and "
                "NOT discriminated by this check: (a) the message names a DATA KEY instead "
                "of its source file (e.g. a shipdata.plist entry name), so the log itself "
                "does not say which expansion contributed it; (b) the engine or a base "
                "resource emitted it; (c) a member's manifest title differs from every "
                "string the message uses. Read the quoted lines to decide."
                % (len(unowned), log_label, primary["identifier"], len(members) - 1,
                   ", ".join(chans)),
                unowned[:20], per)

    return (Verdict.PASS,
            "loaded with its %d-member requires_oxps closure (all named in "
            "searchPaths.dumpAll), reached shipData.load.begin and startup.complete, "
            "%d log lines, 0 ERROR lines attributable to any member"
            % (len(members), len(text.splitlines())), [], per)


def run_group(app_dir: Path, group: dict, work: Path, timeout: float,
              known: dict | None = None) -> dict:
    """Launch the game ONCE with a primary plus its whole dependency closure."""
    name = group["name"]
    result = {
        "name": name, "primary": group["primary"],
        "members": [m["identifier"] for m in group["members"]],
        "missing": group.get("missing", []),
        "verdict": Verdict.LAUNCH, "detail": "", "errors": [],
        "wall_s": 0.0, "rc": None, "per_member": {},
    }

    # UNSATISFIABLE comes FIRST and does not launch anything. A requirement that
    # is not in the corpus means the expansion never got a chance to load;
    # reporting that as a load failure would be a false accusation, and spending
    # a 15-second launch to produce it would be waste.
    if group.get("missing"):
        result["verdict"] = Verdict.UNSATISFIABLE
        result["detail"] = (
            "%s declares requirement(s) that are NOT PRESENT in the corpus at all: %s. "
            "The expansion therefore never got a chance to load, and no launch was "
            "attempted. This is a gap in the cached corpus, NOT a load failure of %s."
            % (name, ", ".join(group["missing"]), name))
        return result

    safe = re.sub(r"\.(oxz|oxp)\b", "_", name, flags=re.I)
    run_dir = work / re.sub(r"[^A-Za-z0-9._-]", "_", safe)[:80]
    if run_dir.exists():
        shutil.rmtree(run_dir, ignore_errors=True)
    addons = run_dir / "AddOns"
    logs = run_dir / "Logs"
    logs.mkdir(parents=True, exist_ok=True)
    addons.mkdir(parents=True, exist_ok=True)

    for m in group["members"]:
        src = Path(m["path"])
        if not src.exists():
            result["verdict"] = "MISSING"
            result["detail"] = ("member %s: no such source path %s - the blob is not in the "
                                "cache" % (m["identifier"], m["path"]))
            return result
        dest = addons / m["staged_as"]
        if src.is_dir():
            shutil.copytree(src, dest)
        else:
            shutil.copyfile(src, dest)
        if not dest.exists():
            result["verdict"] = "MISSING"
            result["detail"] = "member %s: copy reported success but %s is absent" % (
                m["identifier"], dest)
            return result
    if SENTINEL_OXP.is_dir():
        stage(SENTINEL_OXP, addons)

    log_path = logs / "Latest.log"
    result["log"] = str(log_path).replace("\\", "/")
    exe = app_dir / "oolite.exe"
    if not exe.exists():
        result["detail"] = "no oolite.exe at %s" % str(exe).replace("\\", "/")
        return result

    t0 = time.time()
    proc = subprocess.Popen(
        [str(exe), "--no-splash", "-load", SCENARIO_SAVE],
        cwd=str(app_dir), env=_launch_env(logs, addons),
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    try:
        result["rc"] = proc.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        proc.kill()
        try:
            proc.wait(timeout=15)
        except subprocess.TimeoutExpired:
            pass
        result["rc"] = "timeout"
    result["wall_s"] = round(time.time() - t0, 2)

    if not log_path.exists():
        hint = ""
        if result["rc"] == STATUS_DLL_NOT_FOUND:
            hint = (" - that is 0x%X STATUS_DLL_NOT_FOUND: the UCRT64 runtime directory "
                    "is not on PATH, so the process died before its entry point"
                    % STATUS_DLL_NOT_FOUND)
        result["detail"] = ("the game produced NO log at %s (exit %s)%s. It did not run, so "
                            "NO conclusion about ERROR lines is possible."
                            % (result["log"], result["rc"], hint))
        return result

    text = log_path.read_text(encoding="utf-8", errors="replace")
    v, d, errs, per = judge_group(text, group["members"], result["log"],
                                  rc=result["rc"], timeout=timeout)
    if known and name in known:
        all_errs = error_lines(text)
        v, d = apply_known_failure(name, v, d, all_errs, member_sha256s(group["members"]),
                                   known)
        if v in (Verdict.KNOWN, Verdict.KNOWNCHANGED):
            errs = all_errs[:20]
    result["verdict"], result["detail"], result["errors"], result["per_member"] = v, d, errs, per
    return result



def stage(oxp: Path, addons: Path) -> str:
    """Put one expansion into a private AddOns dir; return its basename there."""
    addons.mkdir(parents=True, exist_ok=True)
    dest = addons / oxp.name
    if oxp.is_dir():
        shutil.copytree(oxp, dest)
    else:
        shutil.copyfile(oxp, dest)
    return dest.name


def run_one(app_dir: Path, oxp: Path, work: Path, timeout: float) -> dict:
    """Launch the game with exactly `oxp` staged, and judge the log it writes."""
    # The run dir name must contain NO ".oxz"/".oxp" component. Oolite's
    # -oo_oxzFileExistsAtPath: (NSFileManagerOOExtensions.m:251-266) splits a
    # path at the FIRST component whose extension is oxz and treats everything
    # before it as a zip archive - so a working directory called
    # "foo.oxz/AddOns/..." makes the game try to open that DIRECTORY as a zip,
    # and every expansion under it silently fails to load. Measured: it cost a
    # run of this checker its manifest reads and its search-path entry.
    safe = re.sub(r"\.(oxz|oxp)\b", "_", oxp.name, flags=re.I)
    run_dir = work / re.sub(r"[^A-Za-z0-9._-]", "_", safe)[:80]
    if run_dir.exists():
        shutil.rmtree(run_dir, ignore_errors=True)
    addons = run_dir / "AddOns"
    logs = run_dir / "Logs"
    logs.mkdir(parents=True, exist_ok=True)
    staged = stage(oxp, addons)
    # The sentinel rides along in the SAME private AddOns root: it supplies this
    # run's end-of-run marker and the debugConfig.plist that keeps a sibling's
    # console harness out. It is not the subject of the check, only its witness.
    if SENTINEL_OXP.is_dir():
        stage(SENTINEL_OXP, addons)
    log_path = logs / "Latest.log"

    result = {
        "name": oxp.name, "oxp": str(oxp).replace("\\", "/"), "staged_as": staged,
        "log": str(log_path).replace("\\", "/"), "verdict": Verdict.LAUNCH,
        "detail": "", "errors": [], "wall_s": 0.0, "rc": None,
    }

    exe = app_dir / "oolite.exe"
    if not exe.exists():
        result["detail"] = "no oolite.exe at %s" % str(exe).replace("\\", "/")
        return result

    t0 = time.time()
    proc = subprocess.Popen(
        [str(exe), "--no-splash", "-load", SCENARIO_SAVE],
        cwd=str(app_dir), env=_launch_env(logs, addons),
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    try:
        result["rc"] = proc.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        proc.kill()
        try:
            proc.wait(timeout=15)
        except subprocess.TimeoutExpired:
            pass
        result["rc"] = "timeout"
    result["wall_s"] = round(time.time() - t0, 2)

    # ---- P1 LAUNCH -------------------------------------------------------
    if not log_path.exists():
        hint = ""
        if result["rc"] == STATUS_DLL_NOT_FOUND:
            hint = (" - that is 0x%X STATUS_DLL_NOT_FOUND: the UCRT64 runtime directory is "
                    "not on PATH, so the process died before its entry point"
                    % STATUS_DLL_NOT_FOUND)
        result["detail"] = ("the game produced NO log at %s (exit %s)%s. It did not run, so "
                            "NO conclusion about ERROR lines is possible."
                            % (result["log"], result["rc"], hint))
        return result

    text = log_path.read_text(encoding="utf-8", errors="replace")
    verdict, detail, errors = judge(text, staged, result["log"], rc=result["rc"], timeout=timeout)
    if verdict in (Verdict.LOG, Verdict.NOSHIPDATA) and result["rc"] == BARE_LAUNCH_EXIT:
        detail += (" [exit %d is the bare-launch baseline: the software-GL environment did "
                   "not take effect]" % BARE_LAUNCH_EXIT)
    result["verdict"], result["detail"], result["errors"] = verdict, detail, errors
    return result


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--app-dir", default=os.environ.get("OO_APP_DIR", ""))
    ap.add_argument("--oxp", action="append", default=[])
    ap.add_argument("--work", default="")
    ap.add_argument("--timeout", type=float, default=180.0)
    ap.add_argument("--json", default="")
    ap.add_argument("--judge-log", default="",
                    help="offline: apply the guard to an existing log file and exit")
    ap.add_argument("--expect-staged", default=None,
                    help="with --judge-log: the staged filename P5 should find")
    ap.add_argument("--no-sentinel", action="store_true",
                    help="with --judge-log: skip the P4b own-marker assertion (for judging "
                         "logs captured before the sentinel existed)")
    ap.add_argument("--groups", default="",
                    help="a JSON file of dependency-closure GROUPS (from "
                         "tools/oxp_deps.py tier1 --json). Each group is loaded in ONE "
                         "launch with its primary plus its transitive requires_oxps "
                         "closure, and errors are attributed per member.")
    args = ap.parse_args(argv)

    # --- offline guard mode: no launch, judge a captured log --------------
    if args.judge_log:
        p = Path(args.judge_log)
        if not p.exists():
            print("LAUNCH    %s: no such log file" % args.judge_log)
            return 1
        verdict, detail, errors = judge(
            p.read_text(encoding="utf-8", errors="replace"),
            args.expect_staged, str(p).replace("\\", "/"),
            require_sentinel=not args.no_sentinel)
        print("%-10s %s" % (verdict, detail))
        for ln in errors:
            print("           | %s" % ln)
        return 0 if verdict == Verdict.PASS else 1

    if not args.oxp and not args.groups:
        sys.stderr.write("nothing to do: pass --oxp PATH, --groups FILE or --judge-log FILE\n")
        return 2
    if not args.app_dir:
        sys.stderr.write("LAUNCH: no --app-dir and no OO_APP_DIR; refusing to guess\n")
        return 2
    app_dir = Path(args.app_dir)
    if not app_dir.is_dir():
        sys.stderr.write(
            "LAUNCH: app dir does not exist: %s\n"
            "  The game cannot be launched, so NO conclusion can be drawn about ERROR lines. "
            "Point --app-dir/OO_APP_DIR at the shared build (worktrees contain no build).\n"
            % str(app_dir).replace("\\", "/"))
        return 3

    work = Path(args.work) if args.work else Path(
        os.environ.get("LOCALAPPDATA", os.path.expanduser("~"))) / "Temp" / "oo-het-load"
    work.mkdir(parents=True, exist_ok=True)

    # --- dependency-aware GROUP mode (bead oo-kcrw) ------------------------
    if args.groups:
        groups = json.loads(Path(args.groups).read_text(encoding="utf-8"))
        if not groups:
            sys.stderr.write("the group file is EMPTY - refusing to report success on "
                             "zero checks\n")
            return 2
        try:
            known = load_known_failures()
        except ValueError as exc:
            sys.stderr.write("known-content-failures list is malformed: %s\n" % exc)
            return 2
        results, failed = [], 0
        # NOMANIFEST is NON-FATAL: see the argument at NOMANIFEST_RE. It is
        # still printed with its lines and still counted in the summary, and it is
        # reachable only for an expansion that LOADED and whose every error is the
        # missing-manifest standards complaint. KNOWN (oo-1gc.7, ADR-0047) is the
        # other non-fatal state: an exact, byte-pinned match of a reviewed entry in
        # known-content-failures.json (see apply_known_failure).
        ok_states = GROUP_OK_STATES
        for g in groups:
            r = run_group(app_dir, g, work, args.timeout, known=known)
            results.append(r)
            failed += r["verdict"] not in ok_states
            print("%-10s %-44s %6.1fs  %s"
                  % (r["verdict"], r["name"][:44], r["wall_s"], r["detail"]), flush=True)
            for ln in r["errors"]:
                print("           | %s" % ln, flush=True)
        if args.json:
            Path(args.json).write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
        counts = {}
        for r in results:
            counts[r["verdict"]] = counts.get(r["verdict"], 0) + 1
        print("--- %d group(s) checked, %d failed (%s) ---"
              % (len(results), failed,
                 ", ".join("%s=%d" % kv for kv in sorted(counts.items()))), flush=True)
        return 1 if failed else 0

    results, failed = [], 0
    for spec in args.oxp:
        oxp = Path(spec)
        if not oxp.exists():
            results.append({"name": oxp.name, "oxp": spec, "verdict": "MISSING",
                            "detail": "no such path", "errors": [], "wall_s": 0.0})
            failed += 1
            print("MISSING   %-44s   0.0s  no such path: %s" % (oxp.name, spec), flush=True)
            continue
        r = run_one(app_dir, oxp, work, args.timeout)
        results.append(r)
        failed += r["verdict"] != Verdict.PASS
        print("%-10s %-44s %6.1fs  %s" % (r["verdict"], r["name"], r["wall_s"], r["detail"]),
              flush=True)
        for ln in r["errors"]:
            print("           | %s" % ln, flush=True)

    if args.json:
        Path(args.json).write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")

    print("--- %d checked, %d failed ---" % (len(results), failed), flush=True)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
