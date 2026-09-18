"""Offline checks on a scenario-011-ai-overflow dump: does it prove the AI STACK OVERFLOW was
REACHED and HANDLED, in a game that really had the expansion live?

WHY THIS IS SEPARATE FROM golden_diff.py
----------------------------------------
golden_diff answers "do these two dumps agree", and refuses several ways that question can be
asked vacuously (a file against itself, an empty dump, a collapsed dump, an off-policy
quantisation, floats rounded to whole numbers). All of that is about the COMPARISON.

It cannot answer the other half of the vacuity problem, which is about the RUN. A scenario that
loaded the OXP and dumped a quiet world reproduces byte-for-byte forever and proves nothing about
AI overflow, and so does a scenario that crashed in display init. Two dumps of a dead run agree.
So this file checks the CONTENT, and specifically it checks the thing the scenario is NAMED for.

WHAT COUNTS AS EVIDENCE HERE, IN CAUSAL ORDER
---------------------------------------------
DEFENCE 1 - THE EXPANSION'S SHIP DATA WAS MERGED. `evidence.oxp_ship_keys` is
`Ship.keysForRole('ahruman-stack-overflow-test')` read from the RUNNING game. MEASURED on this
box: `["ahruman-stack-overflow-test"]`. A key is in the registry only if the expansion's
Config/shipdata.plist was merged; being named in `[searchPaths.dumpAll]` proves only that a
DIRECTORY was accepted.

DEFENCE 2 - A PROPERTY WAS READ OFF THAT MERGED ENTRY. `evidence.oxp_ship_ai_type` is
`Ship.shipDataForKey(key).ai_type`, MEASURED as `ahruman-stack-overflow-testAI.plist`. A key in a
list could be a bare name; a property read succeeds only against real merged data. This particular
property is also the registry's own statement that this ship runs the expansion's AI file, which
is what later attributes the overflow to this expansion.

DEFENCE 3 - THE OVERFLOW HAPPENED. `evidence.ai_stack_overflow_events` counts the engine's own
`[ai.error.stackOverflow]` lines from THIS run's Latest.log (AI.m:205-227, raised at :240-246 when
the preserved-state-machine stack reaches kStackLimiter). `ai_stack_overflow_signatures` is the
`<AI file>:<state>` pair taken from those messages - the AI FILE NAME is what attributes the
overflow to this expansion rather than to ambient traffic, and only this expansion can put
`ahruman-stack-overflow-testAI.plist` there. `ai_stack_overflow_max_stack_depth` is the number of
distinct preserved frames the engine dumped and is a STRUCTURAL CONSTANT (AI.m:40 kStackLimiter),
not a stopwatch reading.

DEFENCE 4 - IT WAS HANDLED, NOT MERELY REACHED. `ai_stack_overflow_squashed` counts
`[exception]: Squashing exception OoliteException:AI stack overflow ... in AI handler ...` lines,
and `overflow_handled` is the RELATION `events >= 1 and squashed == events`. An overflow that
escaped its handler leaves the two unequal, and that difference is the finding, not noise.

DEFENCE 5 - THE SIMULATION SURVIVED IT. `evidence.tick_budget_met` is measured on the GAME clock
and the budget is started only AFTER the overflow line is seen in the live log, so a met budget
means the world kept integrating after the engine reported the overflow. A crashed run cannot
produce it.

DEFENCE 6 - THE NOMANIF ALLOWANCE, HELD EXACTLY (bead oo-kcrw). This fixture predates the manifest
format and emits exactly TWO `[oxp-standards.error]: OXP ... has no manifest.plist` lines per
load. The count must be EXACTLY `EXPECTED_STANDARDS_ERRORS` - not "at most", not "at least" - and
every signature must be in the allow-list, compared verbatim after the volatile staged path is
replaced by the OXP basename at capture time. A third line, or a different error, fails. That
exactness is what makes it a tolerance rather than a suppression, and it is what catches a staging
directory named `addons` colliding case-insensitively with the game's own `../AddOns` root (which
loads the expansion twice and produces four lines, bead oo-3ya).

NO MANIFEST IS FABRICATED. The briefing for this bead recorded 'AI overflow test' as failing to
load on a missing manifest. MEASURED here, it loads: ResourceManager.m:642-664 makes the missing
manifest fatal only for an .oxz or under OOEnforceStandards(); for a relaxed-mode .oxp the engine
logs the standards error, synthesises a basic manifest at :654 and adds the path at :663. So no
companion manifest needed staging and none was staged.

EXIT CODES: 0 the dump carries the evidence; 1 it does not (each failure names the field and the
value found). A usage error is 2, the same convention golden_diff uses for "no verdict given".
"""

import argparse
import json
import os
import sys

# Every field the evidence block must carry, with the value a REAL staged run produces. Listed as
# a table rather than as inline ifs so the set is readable and so a future scenario cannot quietly
# drop one of them.
REQUIRED_TRUE = ("oxp_staged", "tick_budget_met", "overflow_handled")
REQUIRED_POSITIVE = ("ticks", "overflow_ships_spawned")

# DEFENCE 1/2: what the running game's ship registry knows about this expansion. MEASURED.
EXPECTED_SHIP_KEYS = frozenset(("ahruman-stack-overflow-test",))
EXPECTED_SHIP_AI_TYPE = "ahruman-stack-overflow-testAI.plist"

# DEFENCE 3: the engine's own overflow report. The depth is AI.m:40 kStackLimiter; the signature
# is <AI file>:<state> from AI.m:212. Pinned as an exact set, not as a floor, so a run that
# overflowed some OTHER ship's AI cannot satisfy this checker.
EXPECTED_OVERFLOW_EVENTS = 1
EXPECTED_MAX_STACK_DEPTH = 32
EXPECTED_OVERFLOW_SIGNATURES = frozenset(("ahruman-stack-overflow-testAI.plist:GLOBAL",))

# DEFENCE 4: the handler that caught it, by exception class and AI handler.
EXPECTED_SQUASH_SIGNATURES = frozenset(
    ("OoliteException in ahruman-stack-overflow-testAI.plist:GLOBAL.ENTER",))

# DEFENCE 6: bead oo-kcrw's NOMANIF allowance, stated exactly.
EXPECTED_STANDARDS_ERRORS = 2
ALLOWED_STANDARDS_ERROR_SIGNATURES = frozenset((
    "OXP AI overflow test.oxp has no manifest.plist",
))

# Floors on the dump's own shape, under what a real run produces, so a truncated or half-written
# dump is rejected here rather than silently compared. This scenario removes its cast before
# dumping and switches the populator off, so the entities are the system's own fixed furniture.
MIN_ENTITIES = 2
MIN_MARKET_GOODS = 10


class EvidenceError(Exception):
    """The dump does not prove an AI stack overflow was reached and handled."""


def check(data, label):
    problems = []

    ev = data.get("evidence")
    if not isinstance(ev, dict):
        raise EvidenceError(
            "%s carries no `evidence` object. A dump without it cannot show that the AI overflow "
            "expansion was ever loaded or that the overflow ever happened, and two such dumps "
            "agreeing proves only that the same nothing happened twice." % label)

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

    # --- DEFENCE 1: the expansion's ship data is MERGED into the running registry --------------
    keys = ev.get("oxp_ship_keys")
    if not isinstance(keys, list) or not keys:
        problems.append(
            "evidence.oxp_ship_keys is %r: the running game's ship registry had no key for the "
            "expansion's role, so its Config/shipdata.plist was never merged. Being on the search "
            "path is not being live." % (keys,))
    elif set(keys) != EXPECTED_SHIP_KEYS:
        problems.append(
            "evidence.oxp_ship_keys is %r, which is not this expansion's measured set %r. A dump "
            "taken with a different expansion loaded is not this scenario."
            % (sorted(keys), sorted(EXPECTED_SHIP_KEYS)))

    # --- DEFENCE 2: a PROPERTY was read off that merged registry entry -------------------------
    ai_type = ev.get("oxp_ship_ai_type")
    if not ai_type:
        problems.append(
            "evidence.oxp_ship_ai_type is %r: no property was read off the registry entry, so the "
            "key above is an unbacked name rather than merged ship data" % (ai_type,))
    elif ai_type != EXPECTED_SHIP_AI_TYPE:
        problems.append(
            "evidence.oxp_ship_ai_type is %r but the measured value is %r. This is the read that "
            "proves merged ship data, and it is the registry's own statement that this ship runs "
            "the expansion's AI file." % (ai_type, EXPECTED_SHIP_AI_TYPE))

    # --- DEFENCE 3: the engine reported the overflow -------------------------------------------
    events = ev.get("ai_stack_overflow_events")
    if not isinstance(events, int) or events < EXPECTED_OVERFLOW_EVENTS:
        problems.append(
            "evidence.ai_stack_overflow_events is %r, expected at least %d: the engine never "
            "logged [ai.error.stackOverflow], so the AI stack overflow this scenario is NAMED for "
            "did not happen. A run that loads the OXP and dumps a quiet world proves nothing and "
            "reproduces byte-for-byte forever." % (events, EXPECTED_OVERFLOW_EVENTS))
    depth = ev.get("ai_stack_overflow_max_stack_depth")
    if depth != EXPECTED_MAX_STACK_DEPTH:
        problems.append(
            "evidence.ai_stack_overflow_max_stack_depth is %r but the measured value is %d "
            "(AI.m:40 kStackLimiter). The depth the engine unwinds is a structural constant, not "
            "a timing artefact, so a different value means the limiter changed and this golden is "
            "stale." % (depth, EXPECTED_MAX_STACK_DEPTH))
    sigs = ev.get("ai_stack_overflow_signatures")
    if not isinstance(sigs, list) or not sigs:
        problems.append(
            "evidence.ai_stack_overflow_signatures is %r: the overflow, if any, cannot be "
            "attributed to this expansion" % (sigs,))
    elif set(sigs) != EXPECTED_OVERFLOW_SIGNATURES:
        problems.append(
            "evidence.ai_stack_overflow_signatures is %r but the measured set is %r. The "
            "signature is <AI file>:<state> from the engine's own message, and the AI file name "
            "is what attributes the overflow to THIS expansion rather than to ambient traffic."
            % (sorted(sigs), sorted(EXPECTED_OVERFLOW_SIGNATURES)))

    # --- DEFENCE 4: it was HANDLED, and the relation holds --------------------------------------
    squashed = ev.get("ai_stack_overflow_squashed")
    if not isinstance(squashed, int) or squashed < 1:
        problems.append(
            "evidence.ai_stack_overflow_squashed is %r: no [exception] Squashing line, so nothing "
            "shows the engine caught what it raised" % (squashed,))
    elif isinstance(events, int) and squashed != events:
        problems.append(
            "the engine reported %r AI stack overflow(s) but %r were squashed. An overflow that "
            "escaped its handler is not 'handled', and the difference is the finding."
            % (events, squashed))
    squash_sigs = ev.get("ai_stack_overflow_squash_signatures")
    if not isinstance(squash_sigs, list) or set(squash_sigs) != EXPECTED_SQUASH_SIGNATURES:
        problems.append(
            "evidence.ai_stack_overflow_squash_signatures is %r but the measured set is %r; this "
            "names the exception class and the AI handler that raised, which is how 'handled' is "
            "distinguished from 'silently absent'."
            % (squash_sigs, sorted(EXPECTED_SQUASH_SIGNATURES)))

    # --- DEFENCE 6: the NOMANIF allowance, held EXACTLY ----------------------------------------
    count = ev.get("oxp_standards_errors")
    if count != EXPECTED_STANDARDS_ERRORS:
        problems.append(
            "evidence.oxp_standards_errors is %r but exactly %d is allowed (bead oo-kcrw: this "
            "fixture is NOMANIF and emits exactly that many "
            "'[oxp-standards.error]: OXP ... has no manifest.plist' lines). Fewer means the "
            "expansion was not parsed; more means a NEW problem. Widening this to make a run pass "
            "is forbidden." % (count, EXPECTED_STANDARDS_ERRORS))
    std_sigs = ev.get("oxp_standards_error_signatures")
    if not isinstance(std_sigs, list):
        problems.append("evidence.oxp_standards_error_signatures is %r, expected a list"
                        % (std_sigs,))
    else:
        unexpected = [s for s in std_sigs if s not in ALLOWED_STANDARDS_ERROR_SIGNATURES]
        if unexpected:
            problems.append(
                "the run emitted an [oxp-standards.error] line that is NOT the known "
                "missing-manifest message: %r. The allow-list is %r and is deliberately exact - a "
                "different error is a finding, not noise."
                % (unexpected, sorted(ALLOWED_STANDARDS_ERROR_SIGNATURES)))
        if not std_sigs:
            problems.append(
                "evidence.oxp_standards_error_signatures is empty: the known missing-manifest "
                "line was never emitted, so this dump was not taken with the expansion staged")

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
    if not (data.get("player") or {}).get("ship"):
        problems.append("player.ship is absent: the dump is not a world-state dump")

    if problems:
        raise EvidenceError("%s does not prove an AI stack overflow run:\n  %s"
                            % (label, "\n  ".join(problems)))

    return ("%s: AI overflow REACHED and HANDLED - ship registry key(s) %s merged with "
            "ai_type=%s; the engine logged %d [ai.error.stackOverflow] (%s) unwinding %d "
            "preserved AI frames, and %d matching Squashing-exception line(s) (%s); exactly %d "
            "known missing-manifest error(s) and no others; the clock advanced %d further ticks "
            "after the overflow; %d entities, %d market goods"
            % (label, ", ".join(sorted(keys)), ai_type, events,
               ", ".join(sorted(sigs)), depth, squashed, ", ".join(sorted(squash_sigs)),
               EXPECTED_STANDARDS_ERRORS, ev["ticks"], len(ents), len(market)))


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
