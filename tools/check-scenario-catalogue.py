#!/usr/bin/env python3
"""Acceptance gate for the 20-scenario golden catalogue (bead oo-9w5).

WHY THIS IS NOT A GREP FOR THREE HEADINGS
-----------------------------------------
oo-9w5 delivers a SPECIFICATION, and a specification's gate has exactly one job: make it
impossible to satisfy the bead with a document that reads well and cannot be built. The three
ways a design document fails are all checked here as data properties, not as prose:

  1. IT IS NOT MACHINE-READABLE, so no later bead can consume it.  --strict parses
     docs/phases/scenario-catalogue.json and refuses anything that is not a complete record.
  2. IT SPECIFIES SOMETHING THAT CANNOT BE BUILT.  Every observable a new scenario names is
     RESOLVED against artefacts that exist today: JS members against the committed API snapshot
     oxp-contract/js-api-1.93.json, log literals against upstream/oolite/src, harness and file
     observables against the filesystem.  An observable that does not resolve and is not marked
     blocked with a named blocker bead fails the gate.  This is the check the fleet has paid for
     five times: S2, S4, S5, S6, S7 and S8 were each parked on an observable that did not exist.
  3. IT DUPLICATES COVERAGE ALREADY BOUGHT.  Each new scenario must carry at least one coverage
     axis that appears nowhere else in the set, and must say in `distinct_from` which existing
     scenarios it is not.

Plus the anti-vacuity discipline the golden tier already runs on (oo-jor, oo-het, oo-gla): every
new scenario must state evidence that the RUN happened - each item naming the field, where it
comes from, and why the harness cannot fabricate it - and must explicitly disown the three
signals this fleet has measured to be vacuous (exit code 0, absence of ERROR lines, the banner).

SUBCOMMANDS
    --strict             the catalogue satisfies every property above
    --selftest           each check is proven to REJECT a targeted mutant of the catalogue,
                         and each mutant is killed BY THE CHECK IT TARGETS
    --cross-check-beads  every bead id named in the catalogue exists in the tracker, and no
                         candidate is still marked blocked on a blocker that has closed
    --check-docs         docs/phases/0-safety-net.md lists all 20 scenarios with a one-line
                         purpose each, agreeing verbatim with the catalogue

EXIT CODES: 0 pass; 1 a real defect, named; 2 the gate could not tell (missing input, bad usage).
rc=2 is never "they agree" - the convention golden_diff.py and check_launch_dock_evidence.py use.
"""

import argparse
import copy
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
CATALOGUE = os.path.join(REPO, "docs", "phases", "scenario-catalogue.json")
API_SNAPSHOT = os.path.join(REPO, "oxp-contract", "js-api-1.93.json")
SRC_DIR = os.path.join(REPO, "upstream", "oolite", "src")
PHASE_DOC = os.path.join(REPO, "docs", "phases", "0-safety-net.md")
DESIGN_DOC = os.path.join(REPO, "docs", "phases", "0-scenarios-18-20.md")
BEADS = os.path.join(REPO, ".beads", "issues.jsonl")

NEW_IDS = ("018", "019", "020")
EXPECTED_COUNT = 20

# The three signals this fleet has MEASURED to be vacuous, each with the incident that proved it.
# A new scenario must disown all three by name, so a future implementer cannot quietly rest on one.
VACUOUS_SIGNALS = {
    "exit code": "oo-het: a bare launch exits 87 after writing a 1476-byte log, and a sibling's "
                 "console can quit a healthy run with rc=0",
    "ERROR": "oo-het: a dead launch writes a log with ZERO ERROR lines, so absence-of-ERROR is "
             "satisfied by a game that never loaded anything",
    "banner": "oo-het: the exit-87 corpse carries the version banner and [process.args]",
}

BEAD_RE = re.compile(r"^oo-[0-9a-z]+$")


class Defect(Exception):
    """A real, named defect in the catalogue."""


class CannotTell(Exception):
    """The gate could not perform its check (rc=2)."""


def _load(path, what):
    if not os.path.isfile(path):
        raise CannotTell("no %s at %s" % (what, path))
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except ValueError as exc:
        raise CannotTell("%s is not valid JSON: %s" % (what, exc))


# --------------------------------------------------------------------- resolvers


def _api_members():
    """{'Ship.equipment', 'Player.credits', 'guiScreen', ...} from the committed API snapshot.

    The snapshot is the machine-checkable form of "this property exists", reproduced by Tier C.
    Resolving against it - rather than against a hand-kept list - is what makes the feasibility
    check honest: if the engine loses a property, the snapshot changes and this gate goes red.
    """
    data = _load(API_SNAPSHOT, "JS API snapshot")
    globals_ = data.get("globals")
    if not isinstance(globals_, dict) or not globals_:
        raise CannotTell("the API snapshot carries no `globals` object")
    out = set()
    for name, entry in globals_.items():
        out.add(name)
        if not isinstance(entry, dict):
            continue
        for bucket in ("prototype_members", "own_members"):
            for member in (entry.get(bucket) or {}):
                out.add("%s.%s" % (name, member))
    return out


def _log_literal_exists(literal):
    """Is this log channel actually emitted by the engine source we ship?"""
    if not os.path.isdir(SRC_DIR):
        raise CannotTell("no engine source at %s" % SRC_DIR)
    try:
        rc = subprocess.call(["grep", "-rqF", "--", literal, SRC_DIR],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError as exc:
        raise CannotTell("cannot run grep: %s" % exc)
    return rc == 0


def _path_exists(expr):
    """`tools/x.py::func` or `path/to/file` -> does the file exist in this checkout?"""
    rel = expr.split("::", 1)[0]
    return os.path.exists(os.path.join(REPO, rel))


def resolve_observable(obs, api):
    """(ok, why_not). Availability is a CLAIM; this is the check of that claim."""
    kind = obs.get("kind")
    expr = obs.get("expr", "")
    if kind == "js":
        if expr in api:
            return True, None
        return False, ("%r does not resolve in the committed JS API snapshot "
                       "(oxp-contract/js-api-1.93.json)" % expr)
    if kind == "log":
        if _log_literal_exists(expr):
            return True, None
        return False, "no engine source under upstream/oolite/src emits the log literal %r" % expr
    if kind in ("harness", "file"):
        if _path_exists(expr):
            return True, None
        return False, "%r names a path that does not exist in this checkout" % expr
    return False, "unknown observable kind %r (expected js, log, harness or file)" % kind


# --------------------------------------------------------------------- the checks
#
# Each check is a function taking the parsed catalogue and raising Defect. They are named, and
# --selftest asserts that the mutant aimed at a check is killed BY THAT CHECK - so a check that
# has quietly become a tautology cannot hide behind a neighbour that happens to fire too.


def check_shape(cat):
    if cat.get("schema") != "oolite-golden-scenarios/1":
        raise Defect("schema is %r, expected 'oolite-golden-scenarios/1'" % cat.get("schema"))
    scen = cat.get("scenarios")
    if not isinstance(scen, list):
        raise Defect("`scenarios` is not a list")
    if len(scen) != EXPECTED_COUNT:
        raise Defect("the catalogue holds %d scenario(s); the exit gate requires %d"
                     % (len(scen), EXPECTED_COUNT))
    ids = [s.get("id") for s in scen]
    if len(set(ids)) != len(ids):
        raise Defect("duplicate scenario id(s): %s"
                     % sorted({i for i in ids if ids.count(i) > 1}))
    want = ["%03d" % n for n in range(1, EXPECTED_COUNT + 1)]
    if ids != want:
        raise Defect("scenario ids are %s; expected %s in order" % (ids, want))


def check_one_line_purpose(cat):
    for s in cat["scenarios"]:
        p = s.get("purpose")
        if not isinstance(p, str) or not p.strip():
            raise Defect("scenario %s has no purpose" % s.get("id"))
        if "\n" in p:
            raise Defect("scenario %s's purpose is not ONE line" % s["id"])
        if len(p) > 400:
            raise Defect("scenario %s's purpose is %d chars; a one-line purpose is <= 400"
                         % (s["id"], len(p)))


def check_knobs(cat):
    """Determinism knobs: a scenario that does not name its seed, system and tick count is not
    reproducible, and 'reproducible across 10 runs from two worktrees' is the exit gate."""
    for s in _new(cat):
        k = s.get("knobs")
        if not isinstance(k, dict):
            raise Defect("scenario %s names no determinism knobs" % s["id"])
        for field, kind in (("seed", int), ("system_id", int), ("ticks", int),
                            ("tick_seconds", (int, float))):
            if field not in k:
                raise Defect("scenario %s does not name its %s knob" % (s["id"], field))
            if not isinstance(k[field], kind) or isinstance(k[field], bool):
                raise Defect("scenario %s's %s knob is %r, not a number" % (s["id"], field, k[field]))
            if k[field] <= 0:
                raise Defect("scenario %s's %s knob is %r, which cannot pin anything"
                             % (s["id"], field, k[field]))


def check_evidence(cat):
    """Anti-vacuity: what proves the RUN happened, not merely that the game started."""
    for s in _new(cat):
        ev = s.get("evidence")
        if not isinstance(ev, list) or len(ev) < 3:
            raise Defect("scenario %s states %s evidence clause(s); a scenario needs at least 3, "
                         "or a run that did nothing satisfies it"
                         % (s["id"], len(ev) if isinstance(ev, list) else "no"))
        fields = []
        for item in ev:
            for key in ("field", "source", "detail", "cannot_be_faked_because"):
                if not item.get(key):
                    raise Defect("scenario %s has an evidence clause missing `%s`: %r"
                                 % (s["id"], key, item.get("field", item)))
            fields.append(item["field"])
        if len(set(fields)) != len(fields):
            raise Defect("scenario %s repeats an evidence field: %s" % (s["id"], fields))
        disowned = " ".join(s.get("not_evidence") or []).lower()
        for signal, why in VACUOUS_SIGNALS.items():
            if signal.lower() not in disowned:
                raise Defect("scenario %s does not disown the vacuous signal %r in `not_evidence` "
                             "(%s)" % (s["id"], signal, why))


def check_observables(cat):
    """THE FEASIBILITY CHECK. Every observable is resolved against something that exists today."""
    api = _api_members()
    for s in _new(cat):
        obs = s.get("observables")
        if not isinstance(obs, list) or not obs:
            raise Defect("scenario %s names no observables, so nothing can be asserted" % s["id"])
        for o in obs:
            claimed = o.get("availability")
            if claimed not in ("today", "blocked"):
                raise Defect("scenario %s observable %r claims availability %r (expected 'today' "
                             "or 'blocked')" % (s["id"], o.get("expr"), claimed))
            ok, why = resolve_observable(o, api)
            if claimed == "today" and not ok:
                raise Defect("scenario %s claims observable %r exists TODAY, but %s. A scenario "
                             "built on it cannot be implemented; mark it blocked and name the "
                             "seam bead." % (s["id"], o.get("expr"), why))
            if claimed == "blocked" and not s.get("blockers"):
                raise Defect("scenario %s has a blocked observable %r but names no blocker bead"
                             % (s["id"], o.get("expr")))


def check_no_duplicate_coverage(cat):
    for s in _new(cat):
        mine = set(s.get("coverage_axes") or [])
        if not mine:
            raise Defect("scenario %s declares no coverage axes" % s["id"])
        others = set()
        for t in cat["scenarios"]:
            if t["id"] != s["id"]:
                others |= set(t.get("coverage_axes") or [])
        novel = mine - others
        if not novel:
            raise Defect("scenario %s adds no coverage: every one of its axes (%s) is already "
                         "covered by another scenario" % (s["id"], sorted(mine)))
        dfrom = s.get("distinct_from")
        if not isinstance(dfrom, dict) or len(dfrom) < 2:
            raise Defect("scenario %s does not argue what it is NOT: `distinct_from` must name at "
                         "least two existing scenarios or tiers" % s["id"])


def check_cost(cat):
    anchors = cat.get("cost_anchors") or {}
    if not anchors:
        raise Defect("the catalogue records no measured cost anchors")
    for s in _new(cat):
        c = s.get("cost") or {}
        secs = c.get("seconds_per_run")
        if not isinstance(secs, (int, float)) or isinstance(secs, bool) or secs <= 0:
            raise Defect("scenario %s states no positive per-run cost" % s["id"])
        used = c.get("basis_anchors") or []
        if not used:
            raise Defect("scenario %s's cost rests on no measured anchor; a cost guessed rather "
                         "than derived cannot be checked" % s["id"])
        for a in used:
            if a not in anchors:
                raise Defect("scenario %s cites cost anchor %r, which is not one of the measured "
                             "anchors %s" % (s["id"], a, sorted(anchors)))


def check_red_means(cat):
    for s in _new(cat):
        rm = s.get("red_means")
        if not isinstance(rm, list) or len(rm) < 3:
            raise Defect("scenario %s describes fewer than 3 RED outcomes; an implementer cannot "
                         "tell what failure means" % s["id"])
        for item in rm:
            if not item.get("symptom") or not item.get("meaning"):
                raise Defect("scenario %s has a RED entry missing symptom or meaning: %r"
                             % (s["id"], item))


def check_evidence_traceability(cat):
    """EVERY evidence clause must be detected by at least one named RED outcome, and every RED
    outcome must name evidence that exists.

    This is the check that catches a SINGLE dropped evidence clause, which a count threshold
    cannot see: a specification that carries five clauses and a specification that carries four
    both clear "at least three", so deleting the one clause that pins a refusal - the awkward,
    valuable one - is free. Requiring the two lists to reference each other makes the evidence set
    and the failure set a closed pair: drop a clause and its RED entry is left pointing at a field
    the catalogue no longer defines, which is reported BY NAME. Drop both and the scenario can no
    longer explain how that failure would ever be noticed.

    This mirrors the discipline check_launch_dock_evidence.py applies to a dump: the properties a
    gate defends are enumerated in a table, so one of them cannot be quietly dropped.
    """
    for s in _new(cat):
        fields = {e["field"] for e in s["evidence"]}
        detected = set()
        for item in s["red_means"]:
            names = item.get("detects")
            if not isinstance(names, list) or not names:
                raise Defect("scenario %s has a RED outcome %r that names no evidence field in "
                             "`detects`: a failure mode nobody can observe is not a failure mode"
                             % (s["id"], item["symptom"][:70]))
            for n in names:
                if n not in fields:
                    raise Defect("scenario %s's RED outcome %r claims to detect %r, which is not "
                                 "one of its evidence fields %s - the failure set and the evidence "
                                 "set have drifted"
                                 % (s["id"], item["symptom"][:70], n, sorted(fields)))
                detected.add(n)
        orphans = fields - detected
        if orphans:
            raise Defect("scenario %s carries evidence field(s) %s that no RED outcome detects: "
                         "the run would collect them and no described failure would ever read "
                         "them" % (s["id"], sorted(orphans)))


def check_not_all_aspirational(cat):
    """At least one new scenario must be buildable with today's observables."""
    buildable = [s["id"] for s in _new(cat)
                 if str(s.get("status", "")).startswith("buildable") and not s.get("blockers")]
    if not buildable:
        raise Defect("no new scenario is buildable today: the whole set is aspirational, which "
                     "is how a specification becomes decoration")
    for s in _new(cat):
        if s.get("blockers") and "blocked" not in str(s.get("status", "")):
            raise Defect("scenario %s names blockers %s but its status is %r; a scenario that "
                         "cannot be built today must SAY so"
                         % (s["id"], s["blockers"], s.get("status")))


def check_rejected_candidates(cat):
    """A rejection is only evidence if it names what is missing and who would supply it."""
    rej = cat.get("rejected_candidates")
    if not isinstance(rej, list) or not rej:
        raise Defect("the catalogue records no rejected candidates, so the selection is a list "
                     "rather than an argument")
    for r in rej:
        for key in ("name", "why_wanted", "why_rejected", "observables_missing"):
            if not r.get(key):
                raise Defect("rejected candidate %r is missing `%s`" % (r.get("name"), key))
        for b in (r.get("blockers") or []):
            if not BEAD_RE.match(b):
                raise Defect("rejected candidate %r names blocker %r, which is not a bead id"
                             % (r["name"], b))


CHECKS = [
    ("shape", check_shape),
    ("one_line_purpose", check_one_line_purpose),
    ("knobs", check_knobs),
    ("evidence", check_evidence),
    ("observables", check_observables),
    ("no_duplicate_coverage", check_no_duplicate_coverage),
    ("cost", check_cost),
    ("red_means", check_red_means),
    ("evidence_traceability", check_evidence_traceability),
    ("not_all_aspirational", check_not_all_aspirational),
    ("rejected_candidates", check_rejected_candidates),
]


def _new(cat):
    return [s for s in cat["scenarios"] if s["id"] in NEW_IDS]


def run_checks(cat):
    """Returns the list of (name, message) that FAILED. Used by --strict and by --selftest."""
    failures = []
    for name, fn in CHECKS:
        try:
            fn(cat)
        except Defect as exc:
            failures.append((name, str(exc)))
    return failures


# --------------------------------------------------------------------- subcommands


def cmd_strict():
    cat = _load(CATALOGUE, "scenario catalogue")
    failures = run_checks(cat)
    if failures:
        for name, msg in failures:
            sys.stderr.write("DEFECT [%s]: %s\n" % (name, msg))
        return 1
    api = _api_members()
    resolved = sum(len(s.get("observables") or []) for s in _new(cat))
    axes = sorted({a for s in _new(cat) for a in s["coverage_axes"]}
                  - {a for s in cat["scenarios"] if s["id"] not in NEW_IDS
                     for a in s.get("coverage_axes") or []})
    print("PASS: %d scenarios (%s new), %d observables resolved against the API snapshot (%d "
          "members), engine source and the tree; %d new coverage axes: %s"
          % (len(cat["scenarios"]), ",".join(NEW_IDS), resolved, len(api), len(axes),
             ", ".join(axes)))
    for s in _new(cat):
        print("  %s %-34s %-32s %3ds/run  %d evidence  %d red  blockers=%s"
              % (s["id"], s["name"], s["status"], s["cost"]["seconds_per_run"],
                 len(s["evidence"]), len(s["red_means"]), s["blockers"] or "none"))
    return 0


# Each mutant names the check it MUST be killed by. A mutant killed only by some other check is
# reported as a failure of this self-test, because it would leave the named check unproven.
def _mutants(cat):
    out = []

    m = copy.deepcopy(cat)
    del _new(m)[0]["evidence"][1:]
    out.append(("evidence", "drop all but one evidence clause from the first new scenario", m))

    m = copy.deepcopy(cat)
    _new(m)[0]["evidence"][0].pop("cannot_be_faked_because")
    out.append(("evidence", "delete an evidence clause's anti-fabrication argument", m))

    m = copy.deepcopy(cat)
    _new(m)[0]["not_evidence"] = ["process exit code 0"]
    out.append(("evidence", "stop disowning absence-of-ERROR as a vacuous signal", m))

    m = copy.deepcopy(cat)
    _new(m)[1]["observables"].append(
        {"expr": "Ship.reportsWhetherItIsHavingFun", "kind": "js", "availability": "today"})
    out.append(("observables", "claim a JS property that does not exist in the API snapshot", m))

    m = copy.deepcopy(cat)
    _new(m)[0]["observables"].append(
        {"expr": "oxp.totallyInventedChannel", "kind": "log", "availability": "today"})
    out.append(("observables", "claim a log channel no engine source emits", m))

    m = copy.deepcopy(cat)
    _new(m)[2]["observables"].append(
        {"expr": "tests/golden/does_not_exist.py::nope", "kind": "harness", "availability": "today"})
    out.append(("observables", "claim a harness file that is not in the tree", m))

    m = copy.deepcopy(cat)
    first = cat["scenarios"][0]
    _new(m)[0]["coverage_axes"] = list(first["coverage_axes"])
    out.append(("no_duplicate_coverage",
                "give a new scenario exactly scenario 001's coverage axes", m))

    m = copy.deepcopy(cat)
    _new(m)[1]["knobs"].pop("seed")
    out.append(("knobs", "remove a scenario's seed knob", m))

    m = copy.deepcopy(cat)
    _new(m)[1]["knobs"]["ticks"] = 0
    out.append(("knobs", "set a scenario's tick budget to zero", m))

    m = copy.deepcopy(cat)
    _new(m)[2]["cost"]["basis_anchors"] = ["it-feels-about-right"]
    out.append(("cost", "cite a cost anchor that was never measured", m))

    m = copy.deepcopy(cat)
    _new(m)[0]["red_means"] = _new(m)[0]["red_means"][:1]
    out.append(("red_means", "leave only one RED outcome described", m))

    # THE MUTANT THAT SURVIVED THE FIRST VERSION OF THIS GATE. Deleting ONE named evidence clause
    # is invisible to a count threshold (5 -> 4 still clears "at least 3"), and the clause a lazy
    # implementer would drop is exactly the awkward one - here scenario 019's REFUSAL evidence,
    # the clause that proves the equipment model is applying rules rather than accepting writes.
    # check_evidence_traceability exists because of this mutant; it is kept as the proof.
    m = copy.deepcopy(cat)
    s = [x for x in _new(m) if x["id"] == "019"][0]
    s["evidence"] = [e for e in s["evidence"]
                     if e["field"] != "evidence.duplicate_award_refused"]
    out.append(("evidence_traceability",
                "delete ONE named evidence clause (019's refusal evidence)", m))

    m = copy.deepcopy(cat)
    _new(m)[2]["red_means"][0].pop("detects")
    out.append(("evidence_traceability",
                "leave a RED outcome naming no evidence field it detects", m))

    m = copy.deepcopy(cat)
    _new(m)[1]["red_means"][0]["detects"] = ["evidence.something_nobody_collects"]
    out.append(("evidence_traceability",
                "have a RED outcome detect an evidence field that does not exist", m))

    m = copy.deepcopy(cat)
    for s in _new(m):
        s["status"] = "blocked"
        s["blockers"] = ["oo-kbqw"]
    out.append(("not_all_aspirational", "mark every new scenario blocked", m))

    m = copy.deepcopy(cat)
    _new(m)[0]["blockers"] = ["oo-kbqw"]
    out.append(("not_all_aspirational",
                "give a scenario a blocker while leaving its status buildable", m))

    m = copy.deepcopy(cat)
    m["scenarios"] = m["scenarios"][:-1]
    out.append(("shape", "drop scenario 020 so the set falls short of 20", m))

    m = copy.deepcopy(cat)
    _new(m)[0]["distinct_from"] = {"001": "it is different"}
    out.append(("no_duplicate_coverage",
                "argue distinctness against only one existing scenario", m))

    m = copy.deepcopy(cat)
    m["rejected_candidates"][0]["blockers"] = ["the AI state seam"]
    out.append(("rejected_candidates", "name a blocker in prose instead of as a bead id", m))

    return out


def cmd_selftest():
    cat = _load(CATALOGUE, "scenario catalogue")
    baseline = run_checks(cat)
    if baseline:
        sys.stderr.write("BASELINE IS RED, so no mutant kill can be attributed: %s\n"
                         % "; ".join("%s: %s" % f for f in baseline))
        return 1
    print("baseline: all %d checks green on the committed catalogue" % len(CHECKS))
    survivors = []
    misattributed = []
    for target, label, mutant in _mutants(cat):
        failed = run_checks(mutant)
        names = [n for n, _ in failed]
        if not failed:
            survivors.append(label)
            print("  SURVIVED  %-62s (expected check `%s` to fire)" % (label, target))
        elif target not in names:
            misattributed.append((label, target, names))
            print("  MISKILL   %-62s killed by %s, not by `%s`" % (label, names, target))
        else:
            msg = dict(failed)[target]
            print("  killed    %-62s [%s] %s" % (label, target, msg[:110]))
    if survivors or misattributed:
        sys.stderr.write("SELFTEST FAILED: %d mutant(s) survived, %d killed by the wrong check\n"
                         % (len(survivors), len(misattributed)))
        return 1
    print("PASS: %d mutants, every one killed by the check it targets; %d checks each proven to "
          "discriminate" % (len(_mutants(cat)), len({t for t, _, _ in _mutants(cat)})))
    return 0


def _beads():
    if not os.path.isfile(BEADS):
        raise CannotTell("no bead tracker at %s" % BEADS)
    rows = {}
    with open(BEADS, "r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                r = json.loads(line)
            except ValueError:
                continue
            if r.get("id"):
                rows[r["id"]] = r
    if not rows:
        raise CannotTell("the bead tracker parsed to zero issues")
    return rows


def cmd_cross_check_beads():
    cat = _load(CATALOGUE, "scenario catalogue")
    rows = _beads()
    problems = []
    checked = 0
    for s in cat["scenarios"]:
        b = s.get("bead")
        if b is None:
            continue
        checked += 1
        if not BEAD_RE.match(b):
            problems.append("scenario %s names bead %r, which is not a bead id" % (s["id"], b))
        elif b not in rows:
            problems.append("scenario %s names bead %s, which is not in the tracker" % (s["id"], b))
    for r in cat.get("rejected_candidates") or []:
        for b in r.get("blockers") or []:
            checked += 1
            if b not in rows:
                problems.append("rejected candidate %r names blocker %s, which is not in the "
                                "tracker" % (r["name"], b))
                continue
            # A rejection whose blocker has CLOSED is stale: the capability may now exist and the
            # candidate deserves re-examination. Silence here would let the argument rot.
            if rows[b].get("status") == "closed":
                problems.append("rejected candidate %r is still blocked on %s, but that bead is "
                                "CLOSED - re-examine the rejection" % (r["name"], b))
    for s in _new(cat):
        for b in s.get("blockers") or []:
            checked += 1
            if b not in rows:
                problems.append("scenario %s names blocker %s, which is not in the tracker"
                                % (s["id"], b))
    if problems:
        for p in problems:
            sys.stderr.write("DEFECT [beads]: %s\n" % p)
        return 1
    print("PASS: %d bead reference(s) resolved against %d tracked issues; no rejection rests on a "
          "closed blocker" % (checked, len(rows)))
    return 0


def cmd_check_docs():
    cat = _load(CATALOGUE, "scenario catalogue")
    if not os.path.isfile(PHASE_DOC):
        raise CannotTell("no phase doc at %s" % PHASE_DOC)
    if not os.path.isfile(DESIGN_DOC):
        raise CannotTell("no design doc at %s" % DESIGN_DOC)
    with open(PHASE_DOC, "r", encoding="utf-8") as handle:
        phase = handle.read()
    with open(DESIGN_DOC, "r", encoding="utf-8") as handle:
        design = handle.read()
    problems = []
    for s in cat["scenarios"]:
        # The bead's own DONE WHEN: 20 scenarios, each with a one-line purpose, in the phase doc.
        if s["purpose"] not in phase:
            problems.append("scenario %s's purpose is absent from %s (the phase doc and the "
                            "catalogue have drifted)" % (s["id"], os.path.basename(PHASE_DOC)))
        if ("| %s " % s["id"]) not in phase and ("**%s**" % s["id"]) not in phase:
            problems.append("scenario %s is not listed in %s"
                            % (s["id"], os.path.basename(PHASE_DOC)))
    for s in _new(cat):
        if s["name"] not in design:
            problems.append("scenario %s (%s) is not specified in %s"
                            % (s["id"], s["name"], os.path.basename(DESIGN_DOC)))
    if os.path.basename(CATALOGUE) not in phase:
        problems.append("%s does not point at the machine-readable catalogue, so a later bead "
                        "cannot find it" % os.path.basename(PHASE_DOC))
    if problems:
        for p in problems:
            sys.stderr.write("DEFECT [docs]: %s\n" % p)
        return 1
    print("PASS: %s lists all %d scenarios with a one-line purpose each, verbatim from %s; %s "
          "specifies %s"
          % (os.path.basename(PHASE_DOC), len(cat["scenarios"]), os.path.basename(CATALOGUE),
             os.path.basename(DESIGN_DOC), ",".join(NEW_IDS)))
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--strict", action="store_true")
    parser.add_argument("--selftest", action="store_true")
    parser.add_argument("--cross-check-beads", action="store_true")
    parser.add_argument("--check-docs", action="store_true")
    args = parser.parse_args(argv)
    chosen = [a for a in ("strict", "selftest", "cross_check_beads", "check_docs")
              if getattr(args, a)]
    if len(chosen) != 1:
        sys.stderr.write("USAGE: exactly one of --strict --selftest --cross-check-beads "
                         "--check-docs\n")
        return 2
    try:
        return {"strict": cmd_strict, "selftest": cmd_selftest,
                "cross_check_beads": cmd_cross_check_beads, "check_docs": cmd_check_docs}[
                    chosen[0]]()
    except CannotTell as exc:
        sys.stderr.write("CANNOT TELL: %s\n" % exc)
        return 2


if __name__ == "__main__":
    sys.exit(main())
