"""Offline checks on a scenario-007-js-interface dump: does it prove the JAVASCRIPT ACTUALLY RAN?

WHY THIS IS SEPARATE FROM golden_diff.py
----------------------------------------
golden_diff answers "do these two dumps agree", and refuses several ways that question can be
asked vacuously (a file against itself, an empty dump, an off-policy quantisation, floats rounded
to whole numbers). All of that is about the COMPARISON. It cannot answer the other half of the
vacuity problem, which is about the RUN.

AND FOR THIS SCENARIO THAT HALF IS THE WHOLE POINT. A JS interface test that silently fails to RUN
produces EXACTLY THE SAME CLEAN LOG as one that ran and passed every assertion: no errors, a
healthy `[startup.complete]`, a perfectly reproducible world. Two runs of a dead scenario agree
byte for byte. Absence of errors is not evidence; it is the default state of a game that did
nothing.

WHAT THIS FILE ASSERTS ON, AND WHY A DEAD RUN CANNOT SATISFY IT
---------------------------------------------------------------
Every clause below is about output THE TEST-OXP ITSELF PRODUCED. Nothing is inferred from silence.

  `js_completion_line`   the rig's own terminal line, verbatim - `All <N> tests passed.` or
                         `***** <F> of <N> tests FAILED`, emitted by completeTests() in
                         upstream/oolite-tests/.../oolite-script-test-rig.js. Nothing in the
                         harness produces that string. A run in which the scripts never executed
                         has an EMPTY line here and is rejected by name.
  `js_tests_total`       the N out of that same line.
  `js_pass_lines` /      per-test results from printResult(), which renders
  `js_fail_lines`        `Pass: <name>` / `FAIL: <name> -- <error>`. These are counted
                         INDEPENDENTLY of the completion line, and the two must AGREE: they come
                         from different functions in the rig, so a disagreement means results
                         were lost in transit and is fatal.
  `js_test_names_sha256` SHA-256 of the sorted, newline-joined set of test names reported. The
                         names exist ONLY inside the expansion's `$registerTest(...)` call sites.
                         A dead run hashes the empty set - a different, known digest, rejected
                         explicitly - and a run that silently loses tests moves the digest even
                         when the counts still look plausible.
  `oxp_nomanifest_errors` EXACTLY 2 (see the allow-list argument in js_interface.py). Pinned as a
                         dump field so a third such line fails the ordinary diff as well.

A LOWER BOUND ON THE ASSERTION COUNT IS PART OF THE GATE. `MIN_JS_TESTS` is far below what the
expansion actually registers, so it does not re-pin the golden's exact content (that is the
golden's job) - but a rig that reported "All 1 tests passed." would be a rig whose scripts mostly
failed to register, and that is exactly the quiet degradation this file exists to catch.

EXIT CODES: 0 the dump proves the JS ran; 1 it does not (each failure names the field and the
value found); 2 a usage error - "I cannot tell you", never "they match" (golden_diff's convention).
"""

import argparse
import hashlib
import json
import os
import sys

# Fields that must be present and TRUE.
REQUIRED_TRUE = ("js_rig_loaded", "oxp_named_in_log", "tick_budget_met")

# Fields that must be present and >= 1.
REQUIRED_POSITIVE = ("js_tests_total", "js_pass_lines", "js_result_lines",
                     "js_world_script_count", "js_staged_scripts", "ticks")

#: The expansion registers dozens of tests across five script files. This floor is far under that,
#: so it catches "the rig loaded but almost nothing registered" without re-pinning the content.
MIN_JS_TESTS = 10

#: The exact, non-negotiable count of `has no manifest.plist` error lines allowed, by the
#: allow-list argued in js_interface.py. An EXACT count, not a floor.
EXPECTED_NOMANIF_LINES = 2

#: The digest of the EMPTY name set. Named as a constant so the rejection message can say what
#: the value means rather than printing 64 opaque hex characters.
EMPTY_NAMES_SHA256 = hashlib.sha256(b"").hexdigest()

MIN_ENTITIES = 2
MIN_MARKET_GOODS = 10


class EvidenceError(Exception):
    """The dump does not prove the JavaScript ran."""


def check(data, label):
    problems = []

    ev = data.get("evidence")
    if not isinstance(ev, dict):
        raise EvidenceError(
            "%s carries no `evidence` object. A dump without it cannot show that a single line of "
            "the expansion's JavaScript ever executed, and two such dumps agreeing proves only "
            "that the same nothing happened twice." % label)

    for field in REQUIRED_TRUE:
        if field not in ev:
            problems.append("evidence.%s is ABSENT" % field)
        elif ev[field] is not True:
            problems.append("evidence.%s is %r, expected True" % (field, ev[field]))

    for field in REQUIRED_POSITIVE:
        if field not in ev:
            problems.append("evidence.%s is ABSENT" % field)
        elif not isinstance(ev[field], int) or ev[field] < 1:
            problems.append("evidence.%s is %r, expected an integer >= 1" % (field, ev[field]))

    if "populators_suppressed" not in ev:
        problems.append("evidence.populators_suppressed is ABSENT: this dump predates the "
                        "populator suppression and may have been taken in a world the system "
                        "was still adding traffic to")

    # --- THE CENTRAL CLAUSE: the rig's own completion line ------------------------------------
    completion = ev.get("js_completion_line")
    if not isinstance(completion, str) or not completion.strip():
        problems.append(
            "THE JAVASCRIPT DID NOT RUN TO COMPLETION: evidence.js_completion_line is %r. That "
            "string is produced ONLY by completeTests() in oolite-script-test-rig.js; the harness "
            "cannot write it. Its absence is the signature of a run in which the expansion's "
            "scripts never executed - which produces a log indistinguishable from a passing run."
            % completion)
    elif not (completion.startswith("All ") or completion.startswith("*****")):
        problems.append(
            "evidence.js_completion_line is %r, which matches neither spelling completeTests() "
            "produces (`All <N> tests passed.` / `***** <F> of <N> tests FAILED`)" % completion)

    total = ev.get("js_tests_total")
    if isinstance(total, int) and total < MIN_JS_TESTS:
        problems.append(
            "evidence.js_tests_total is %d, below the floor of %d. The expansion registers "
            "dozens of tests across five script files, so a total this low means most of them "
            "never registered - a quiet degradation that leaves the log clean"
            % (total, MIN_JS_TESTS))

    # The two counters come from DIFFERENT functions in the rig (printResult vs completeTests), so
    # requiring them to agree is a real cross-check and not a restatement.
    passes, fails = ev.get("js_pass_lines"), ev.get("js_fail_lines")
    if isinstance(passes, int) and isinstance(fails, int) and isinstance(total, int):
        if passes + fails != total:
            problems.append(
                "evidence: %d pass + %d fail result line(s) but the completion line reports %d "
                "test(s). printResult() and completeTests() are different functions in the rig; "
                "a disagreement means results were lost." % (passes, fails, total))

    # --- the digest: a field that cannot exist unless the expansion's scripts ran --------------
    digest = ev.get("js_test_names_sha256")
    if not isinstance(digest, str) or len(digest) != 64:
        problems.append("evidence.js_test_names_sha256 is %r, not a 64-character SHA-256 digest"
                        % digest)
    elif digest == EMPTY_NAMES_SHA256:
        problems.append(
            "evidence.js_test_names_sha256 is the digest of the EMPTY test-name set (%s): the "
            "rig reported no test names at all, so its $registerTest() call sites - which live "
            "only inside the expansion - never ran" % EMPTY_NAMES_SHA256)
    elif set(digest) == {"0"}:
        problems.append(
            "evidence.js_test_names_sha256 is all zeroes: that is a placeholder, not a digest of "
            "anything the rig reported")

    # --- the NOMANIF allow-list, pinned by EXACT count ----------------------------------------
    nomanif = ev.get("oxp_nomanifest_errors")
    if nomanif is None:
        problems.append("evidence.oxp_nomanifest_errors is ABSENT: this dump does not record how "
                        "many no-manifest error lines the run produced, so the allow-list cannot "
                        "be checked at all")
    elif nomanif != EXPECTED_NOMANIF_LINES:
        problems.append(
            "evidence.oxp_nomanifest_errors is %r, not the pinned %d. The expansion is a legacy "
            "in-tree fixture that emits EXACTLY %d such lines (bead oo-kcrw measured that count "
            "across five unrelated fixtures); a different number means either an extra error "
            "appeared or the expansion was not loaded the way this golden was blessed"
            % (nomanif, EXPECTED_NOMANIF_LINES, EXPECTED_NOMANIF_LINES))

    # --- the dump's own shape ------------------------------------------------------------------
    ents = data.get("entities")
    if not isinstance(ents, list) or len(ents) < MIN_ENTITIES:
        problems.append("entities has %r member(s), fewer than the %d a real run of this scenario "
                        "carries" % (len(ents) if isinstance(ents, list) else ents, MIN_ENTITIES))
    market = data.get("market")
    if not isinstance(market, dict) or len(market) < MIN_MARKET_GOODS:
        problems.append("market has %r good(s), fewer than the %d minimum; the station's market "
                        "is missing, so the dump is not a docked world state"
                        % (len(market) if isinstance(market, dict) else market, MIN_MARKET_GOODS))

    if problems:
        raise EvidenceError("%s does not prove the JavaScript interface was exercised:\n  %s"
                            % (label, "\n  ".join(problems)))

    return ("%s: the expansion's own rig reported %r - %d pass, %d fail across %d test(s); "
            "names digest %s...; %d allow-listed no-manifest line(s); %d entities, %d market goods"
            % (label, ev["js_completion_line"], ev["js_pass_lines"], ev["js_fail_lines"],
               ev["js_tests_total"], ev["js_test_names_sha256"][:12],
               ev["oxp_nomanifest_errors"], len(ents), len(market)))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("dump")
    parser.add_argument("--label", default=None)
    args = parser.parse_args(argv)
    label = args.label or args.dump

    if not os.path.isfile(args.dump):
        sys.stderr.write("USAGE: no such dump: %s\n" % args.dump)
        return 2
    try:
        with open(args.dump, "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except ValueError as exc:
        sys.stderr.write("USAGE: %s is not valid JSON: %s\n" % (label, exc))
        return 2

    try:
        print(check(data, label))
    except EvidenceError as exc:
        sys.stderr.write("NO EVIDENCE: %s\n" % exc)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
