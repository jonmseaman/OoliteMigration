import json
import os
import sys

"""Gate: the blessed golden agrees with the differential recorded in provenance, and the control
arms genuinely move the mission state. Kept as a FILE rather than inlined into the acceptance
block because the check needs a loop, and a loop written with literal \\n escapes inside a
single-quoted `python -c` argument is not a loop - bash passes the backslash through verbatim and
python sees one syntactically broken line.

A save-load golden that only proves 'the game started' would pass just as well against a default
new commander with no mission at all. This asserts the recorded control arms MOVE named
mission-state fields, so that vacuity is excluded by measurement rather than by assertion.
"""

FIELDS = ("commander_name", "system_name", "system_id", "mission_conhunt",
          "mission_conhunt_present", "mission_variable_names", "live_mission_handlers",
          "mission_script_loaded")

SUBJECT_FIELDS = ("commander_name", "system_name", "system_id", "mission_conhunt",
                  "mission_conhunt_present", "live_mission_handlers", "mission_script_loaded")


def main(golden_path, provenance_path):
    with open(golden_path, "r", encoding="utf-8") as fh:
        dump = json.load(fh)
    with open(provenance_path, "r", encoding="utf-8") as fh:
        prov = json.load(fh)

    ev = dump.get("evidence") or {}
    md = prov.get("mission_state_differential")
    if not md:
        return ("FAIL: %s records no mission_state_differential; without a measured control arm, "
                "the claim that this dump observes the LOADED SAVE rather than merely that a game "
                "started is unsupported" % provenance_path)

    sub = md.get("subject") or {}
    for key in SUBJECT_FIELDS:
        if sub.get(key) != ev.get(key):
            return ("FAIL: provenance subject.%s=%r but the blessed golden reports %r; the "
                    "differential was measured against a different dump than the one blessed"
                    % (key, sub.get(key), ev.get(key)))

    arms = [a for a in ("control_thargoidplans", "control_fresh_game") if a in md]
    if len(arms) < 2:
        return ("FAIL: provenance records %d control arm(s); the differential needs a DIFFERENT "
                "save AND a no-save arm" % len(arms))

    total = 0
    for arm_name in arms:
        arm = md[arm_name]
        moved = [f for f in FIELDS if arm.get(f) != sub.get(f)]
        if not moved:
            return ("FAIL: control arm %r moves NO mission-state field against the subject: the "
                    "dump does not observe the loaded save at all, so the golden would pass "
                    "against that arm and is vacuous" % arm_name)
        total += len(moved)
        print("  %-24s %d/%d mission-state field(s) MOVED: %s"
              % (arm_name, len(moved), len(FIELDS),
                 ", ".join("%s %r->%r" % (f, sub.get(f), arm.get(f)) for f in moved)))

    if all(md[a].get("mission_conhunt") == sub.get("mission_conhunt") for a in arms):
        return ("FAIL: mission_conhunt does not move against ANY control arm; the field this bead "
                "names is not observed by the dump")
    if all(md[a].get("live_mission_handlers") == sub.get("live_mission_handlers") for a in arms):
        return ("FAIL: live_mission_handlers does not move against ANY control arm; the POSITIVE "
                "half of the mission-state assertion is not observed")

    ctl = md["control_thargoidplans"]
    print("PASS: the blessed golden agrees field-for-field with the differential subject recorded "
          "in provenance, and %d mission-state field movements across %d control arms prove the "
          "dump observes WHICH SAVE was loaded. mission_conhunt moves %r -> %r against the "
          "ThargoidPlans arm and live_mission_handlers moves %r -> %r; neither a default new game "
          "nor a dead run can produce the subject's values."
          % (total, len(arms), sub.get("mission_conhunt"), ctl.get("mission_conhunt"),
             sub.get("live_mission_handlers"), ctl.get("live_mission_handlers")))
    return None


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.stderr.write("usage: gate_013_differential.py <state.json> <provenance.json>\n")
        sys.exit(2)
    for path in sys.argv[1:]:
        if not os.path.isfile(path):
            sys.stderr.write("USAGE: no such file: %s\n" % path)
            sys.exit(2)
    problem = main(sys.argv[1], sys.argv[2])
    if problem:
        sys.stderr.write(problem + "\n")
        sys.exit(1)
