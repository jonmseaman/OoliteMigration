"""Offline checks on a scenario-018 dump: does it prove a DIFFERENTIAL between two launches?

WHY THIS IS SEPARATE FROM golden_diff.py
----------------------------------------
golden_diff answers "do these two dumps agree", and refuses several ways that question can be
asked vacuously. All of that is about the COMPARISON. It cannot answer the other half of the
vacuity problem, which is about the RUN - and for an expansion-LOADING scenario that half is
unusually sharp, because a run that staged nothing, or that never launched at all, still exits 0
and still writes a log with no ERROR lines in it (bead oo-het's exit-87 corpse: banner,
[process.args], zero ERROR lines, nothing loaded).

So every check below is POSITIVE and every one names a fact that only a pair of REAL, DIFFERENTLY
STAGED launches can produce.

THE SIX DEFENCES, AND WHAT EACH ONE CATCHES
-------------------------------------------
1. THE CLOSURE ARM LOADED. `primary_in_search_paths` and `dependency_in_search_paths`. An
   expansion reaches the `[searchPaths.dumpAll]` block only through `checkPotentialPath`
   (ResourceManager.m:613-664), i.e. only after its manifest.plist was read and its identifier,
   version, title and required_oolite_version validated. A file merely sitting in the AddOns
   directory does NOT appear there. Both are required: the primary alone would go green on a run
   whose "closure" was one member.

2. THE CONTROL ARM WAS REFUSED. `control_primary_in_search_paths` must be FALSE. This is the
   negative control, and it is the clause the whole scenario exists for: if requirement
   resolution (`filterSearchPathsForRequirements`, ResourceManager.m:949-975) stops enforcing
   `requires_oxps`, expansions load with unmet dependencies and break silently for every user.

3. THE REFUSAL WAS DIAGNOSED. `control_requirement_missing`, plus
   `closure_requirement_missing_lines` EMPTY. Absence from the search paths alone cannot
   distinguish a refusal from a staging bug; `[oxp.requirementMissing]` (ResourceManager.m:941) is
   the engine SAYING it refused. And it must appear in exactly one of the two arms - if both emit
   it, the control proves nothing about the closure.

4. BOTH RUNS FINISHED LOADING. `startup_complete_both_runs`. A marker emitted after expansion
   parsing; the exit-87 corpse carries the banner and [process.args] and never reaches it. Without
   it in both arms, every other signal in the differential is void.

5. THE MANIFEST-LESS FIXTURE, EXACTLY. The count of `[oxp-standards.error]` lines attributed to
   the fixture is EQUAL to the pinned number in BOTH runs, every signature is on the allow-list,
   no standards line is unattributed, and the fixture IS in the search paths of both runs
   (ResourceManager.m:642-664 synthesises a manifest for an .oxp in relaxed mode, so the complaint
   is informational - if the fixture stopped loading, load BEHAVIOUR changed, not logging).

6. THE COMPOSITION IS THE ONE THAT WAS BLESSED. `staged_identifiers == recomputed_closure`, and
   the two arms' search-path blocks must DIFFER. Two identical blocks mean the staging difference
   never reached the engine and both arms measured the same thing.

THE FRAME IS NOT CHECKED HERE. llvmpipe is not bit-reproducible - this scenario's own sweep
produced 10 distinct frame digests over 10 BYTE-IDENTICAL dumps - so the frame carries a LIVENESS
assertion only, applied by `expansion_closure.py --check-frame`, never a digest.

Usage:
    python3 tests/golden/check_018_evidence.py [PATH_TO_state.json]
"""

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, ".."))
sys.path.insert(0, HERE)

SCENARIO = "018-expansion-closure-and-manifestless"

GOLDEN_CANDIDATES = (
    os.path.join(REPO_ROOT, "..", "goldens", "windows-x64", SCENARIO, "state.json"),
    os.path.join(HERE, "pending", SCENARIO, "state.json"),
)
SPEC_CANDIDATES = (
    os.path.join(HERE, "scenarios", SCENARIO, "spec.json"),
    os.path.join(HERE, "pending", SCENARIO, "spec.json"),
)

#: Fields that must be present AND true. Each is named by a RED outcome in
#: docs/phases/scenario-catalogue.json; a count floor would not distinguish five clauses from
#: four, and the clause a future editor drops is always the awkward one (bead oo-9w5).
REQUIRED_TRUE = (
    "primary_in_search_paths",
    "dependency_in_search_paths",
    "control_requirement_missing",
    "startup_complete_both_runs",
    "closure_startup_complete",
    "control_startup_complete",
    "manifestless_in_search_paths_both_runs",
    "closure_tick_budget_met",
    "control_tick_budget_met",
)

#: Fields that must be present AND false. `control_primary_in_search_paths` is the negative
#: control: a checker that only ever asserts truth cannot express "this must NOT have happened".
REQUIRED_FALSE = ("control_primary_in_search_paths",)

#: The four properties that get their OWN named clause below rather than being judged by the
#: shared sweep. Each names a distinct RED outcome in docs/phases/scenario-catalogue.json, and
#: each is pinned by its own checker mutant in tests/golden/test_expansion_closure.py.
NAMED_CLAUSES = (
    "primary_in_search_paths",
    "dependency_in_search_paths",
    "startup_complete_both_runs",
    "manifestless_in_search_paths_both_runs",
)


class EvidenceError(RuntimeError):
    pass


def _first(candidates, what):
    for path in candidates:
        if os.path.isfile(path):
            return path
    raise EvidenceError("no %s found; looked in: %s" % (what, ", ".join(candidates)))


def load(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def check(state, spec, label):
    problems = []
    evidence = state.get("evidence")
    if not isinstance(evidence, dict):
        raise EvidenceError(
            "%s carries no evidence block. A dump of world state alone proves the game was "
            "running; it cannot prove which expansions loaded." % label)

    # --- PRESENCE, for every judged field ------------------------------------
    # A separate clause from the value checks below, because a MISSING field and a FALSE field
    # are different failures: the first means the dump cannot be judged at all, the second is a
    # verdict. A checker that conflates them reports "must be true" about a field that is not
    # there, and the next reader looks for a bug in the engine instead of in the dump format.
    for key in REQUIRED_TRUE + REQUIRED_FALSE:
        if key not in evidence:
            problems.append("evidence.%s is MISSING - the dump cannot be judged on a field it "
                            "does not carry" % key)

    # --- THE FOUR LOAD-BEARING PROPERTIES, each with its OWN clause -----------
    # Deliberately NOT a loop over REQUIRED_TRUE: a loop gives every property one shared
    # predicate, so a single `if False:` disables all of them at once and a mutation suite can
    # only ever prove that ONE thing is defended. Each of these four names a distinct RED outcome
    # in docs/phases/scenario-catalogue.json and each is pinned by its own mutant.
    if evidence.get("primary_in_search_paths") is False:
        problems.append(
            "evidence.primary_in_search_paths is false: the CLOSURE run staged the primary "
            "together with its whole requires_oxps closure and the engine still did not accept "
            "it. An expansion reaches [searchPaths.dumpAll] only through checkPotentialPath "
            "(ResourceManager.m:613-664), so this run has no positive arm at all.")
    if evidence.get("dependency_in_search_paths") is False:
        problems.append(
            "evidence.dependency_in_search_paths is false: the primary may have loaded for some "
            "other reason, but the CLOSURE was not actually composed, so this dump does not "
            "measure dependency resolution.")
    if evidence.get("startup_complete_both_runs") is False:
        problems.append(
            "evidence.startup_complete_both_runs is false: at least one arm never reached "
            "[startup.complete]. Bead oo-het's exit-87 corpse carries the version banner and "
            "[process.args] with ZERO ERROR lines and never reaches that marker, so without it "
            "in BOTH arms every other signal in this differential is void.")
    if evidence.get("manifestless_in_search_paths_both_runs") is False:
        problems.append(
            "evidence.manifestless_in_search_paths_both_runs is false: the manifest-less fixture "
            "stopped loading. ResourceManager.m:642-664 SYNTHESISES a manifest for an .oxp in "
            "relaxed mode and adds the path, so its absence means load BEHAVIOUR changed, not "
            "logging.")

    # --- THE NEGATIVE CONTROL -------------------------------------------------
    # The one clause that asserts something did NOT happen. A checker that only ever asserts
    # truth cannot express a refusal, and a refusal is what this scenario exists to observe.
    if evidence.get("control_primary_in_search_paths") is not False:
        problems.append(
            "evidence.control_primary_in_search_paths is %r, must be FALSE. The control run "
            "staged the primary WITHOUT its declared requirement; if the engine loaded it anyway, "
            "requirement resolution (ResourceManager.m:949-975) has stopped enforcing "
            "requires_oxps and expansions now load with unmet dependencies."
            % (evidence.get("control_primary_in_search_paths"),))

    # --- the remaining REQUIRED_TRUE fields, as a completeness sweep ----------
    # NAMED_CLAUSES is excluded so each of the four above is the SOLE defence of its property.
    # Leaving them in would make every one of them redundantly defended, and a mutation suite
    # cannot distinguish a redundantly-defended property from an undefended one - it just reports
    # a survivor and sends the next reader to 'fix' a correct gate (bead oo-jor).
    for key in REQUIRED_TRUE:
        if key in NAMED_CLAUSES:
            continue
        if key in evidence and evidence[key] is not True:
            problems.append("evidence.%s is %r, must be true" % (key, evidence[key]))

    # --- the standards-error count, EXACT, in BOTH arms ---------------------
    allowed = int(spec["allowed_manifestless_standards_errors"])
    allowed_sigs = set(spec["allowed_manifestless_standards_error_signatures"])
    for arm in ("closure", "control"):
        got = evidence.get("%s_nomanif_standards_errors" % arm)
        if got != allowed:
            problems.append(
                "evidence.%s_nomanif_standards_errors is %r but the spec pins exactly %d for the "
                "manifest-less fixture. A count above means new complaints, below means "
                "complaints were lost; widening the number to make a run pass is forbidden."
                % (arm, got, allowed))
        sigs = evidence.get("%s_nomanif_standards_error_signatures" % arm) or []
        if not sigs:
            problems.append(
                "evidence.%s_nomanif_standards_error_signatures is empty: a count with no message "
                "behind it cannot be audited" % arm)
        for sig in sigs:
            if sig not in allowed_sigs:
                problems.append(
                    "evidence.%s_nomanif_standards_error_signatures carries %r, which is not the "
                    "known missing-manifest message %r - a different complaint is a finding, not "
                    "noise" % (arm, sig, sorted(allowed_sigs)))
        unowned = evidence.get("%s_unattributed_standards_errors" % arm)
        if unowned:
            problems.append(
                "evidence.%s_unattributed_standards_errors is %r: a standards error no staged "
                "expansion claims must never be folded into the fixture's allowance" % (arm, unowned))

    # --- the refusal diagnostic, present in exactly ONE arm ------------------
    if evidence.get("closure_requirement_missing_lines"):
        problems.append(
            "evidence.closure_requirement_missing_lines is %r: the CLOSURE run also logged "
            "[oxp.requirementMissing], so the two arms do not differ in this line and the control "
            "proves nothing about the closure."
            % (evidence["closure_requirement_missing_lines"],))
    lines = evidence.get("control_requirement_missing_lines") or []
    primary = evidence.get("primary_identifier", "")
    if not any(primary and primary in ln for ln in lines):
        problems.append(
            "no line in evidence.control_requirement_missing_lines names the primary %r (lines: "
            "%r). The refusal must be attributed to the expansion under test; a requirementMissing "
            "line about something else does not prove this scenario's expansion was refused."
            % (primary, lines))

    # --- the composition, and the differential itself ------------------------
    staged = evidence.get("staged_identifiers")
    recomputed = evidence.get("recomputed_closure")
    if not staged or not recomputed:
        problems.append("evidence.staged_identifiers / recomputed_closure are missing or empty; "
                        "without them the golden does not record what composition it measured")
    elif staged != recomputed:
        problems.append(
            "evidence.staged_identifiers %r != evidence.recomputed_closure %r: the identifier "
            "index or the dependency walk changed, so the run measured a different composition "
            "than the golden claims" % (staged, recomputed))
    elif len(staged) < 2:
        problems.append(
            "evidence.staged_identifiers is %r - fewer than two members, so there was no "
            "DEPENDENCY to withhold and the control arm was identical to the closure arm. This "
            "scenario requires a primary with a non-empty requires_oxps." % (staged,))

    if evidence.get("control_staged_identifiers") == staged:
        problems.append(
            "evidence.control_staged_identifiers equals the closure arm's %r: the two launches "
            "were staged IDENTICALLY, so this dump is not a differential at all" % (staged,))

    if evidence.get("closure_search_path_names") == evidence.get("control_search_path_names"):
        problems.append(
            "the two runs' [searchPaths.dumpAll] blocks are IDENTICAL (%r): the staging difference "
            "never reached the engine and both arms measured the same thing"
            % (evidence.get("closure_search_path_names"),))

    if evidence.get("scenario") != SCENARIO:
        problems.append("evidence.scenario is %r, not %r"
                        % (evidence.get("scenario"), SCENARIO))

    if problems:
        raise EvidenceError("%s does NOT prove the expansion-closure differential:\n  - %s"
                            % (label, "\n  - ".join(problems)))

    print("PASS: %s proves the differential - %s loaded WITH its closure %r (dependency %s also "
          "in the search paths) and was REFUSED without it, with [oxp.requirementMissing] in the "
          "control run only; both runs reached [startup.complete]; the manifest-less fixture %s "
          "loaded and emitted exactly %d standards error(s) in each run, all attributed."
          % (label, evidence["primary_staged_as"], staged, evidence["dependency_staged_as"],
             evidence["manifestless_staged_as"], evidence["closure_nomanif_standards_errors"]))
    return 0


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    try:
        path = argv[0] if argv else _first(GOLDEN_CANDIDATES, "stored golden for " + SCENARIO)
        spec = load(_first(SPEC_CANDIDATES, "spec.json for " + SCENARIO))
        return check(load(path), spec, path)
    except EvidenceError as exc:
        print("[!] %s" % exc, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
