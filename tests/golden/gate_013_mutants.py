"""Gate: prove the scenario-013 evidence checker can go RED.

For each named property this gate defends, a THROWAWAY COPY of the stored golden is corrupted in
the way a wrong-save or a dead run corrupts it, and the checker must return rc=1. The real golden
is never touched: it is read once and every mutant is written under a temp directory.

A gate nobody has seen go red is not known to be a gate, and this is the DATA half of the
two-mutant rule (bead oo-jor). The CHECKER half - weakening the validator itself - lives in
tests/golden/test_constrictor_save.py, which mutates copies of the checker source.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
CHECKER = os.path.join(HERE, "check_constrictor_evidence.py")

MUTANTS = (
    ("wrong_conhunt", "mission_conhunt set to MISSION_COMPLETE (the completed-mission save)"),
    ("empty_missionvars", "mission_variables emptied (a default new commander)"),
    ("no_handlers", "the live mission handlers emptied (wrong-save / dead-run signature)"),
    ("wrong_commander", "the commander swapped for the engine default"),
    ("wrong_score", "ship_kills moved by one, past the mission script's own threshold"),
    ("desync_top", "the dump's top-level mission_variables desynchronised from evidence"),
    ("wrong_save_file", "the save file swapped for another checklist save"),
    ("no_evidence", "the evidence block removed entirely"),
)

# A GATE THAT RUNS ZERO MUTANTS PRINTS PASS. Measured: emptying MUTANTS left this file exiting 0
# with the message "all 0 data mutants ... are REJECTED", which is true and worthless. The floor
# closes that hole from inside the gate itself, so the emptying mutation is now fatal here rather
# than invisible. tests/golden/test_constrictor_save.py pins the same number from outside.
MIN_MUTANTS = 8


def apply(data, name):
    ev = data.get("evidence")
    if name == "wrong_conhunt":
        ev["mission_conhunt"] = "MISSION_COMPLETE"
        ev["mission_conhunt_present"] = True
    elif name == "empty_missionvars":
        ev["mission_variables"] = {}
        data["mission_variables"] = {}
    elif name == "no_handlers":
        ev["live_mission_handlers"] = []
    elif name == "wrong_commander":
        ev["commander_name"] = "Jameson"
    elif name == "wrong_score":
        ev["score"] = 256
    elif name == "desync_top":
        data["mission_variables"] = {"trumbles": "NOT_NOW"}
    elif name == "wrong_save_file":
        ev["save_file"] = "ThargoidPlans.oolite-save"
    elif name == "no_evidence":
        data.pop("evidence")
    else:
        raise SystemExit("unknown mutant %r" % name)
    return data


def main(golden_path):
    if len(MUTANTS) < MIN_MUTANTS:
        print("FAIL: this gate carries %d mutant(s), fewer than the %d floor. A mutation gate that "
              "runs no mutants exits 0 and reports 'all 0 mutants rejected' - true, and exactly as "
              "useful as no gate at all. Restore the mutants; do NOT lower the floor."
              % (len(MUTANTS), MIN_MUTANTS))
        return 1

    with open(golden_path, "r", encoding="utf-8") as fh:
        original = fh.read()

    work = tempfile.mkdtemp(prefix="oo_5h8e_mut_")
    failures = 0
    try:
        for name, description in MUTANTS:
            data = apply(json.loads(original), name)
            path = os.path.join(work, "%s.json" % name)
            with open(path, "w", encoding="utf-8") as fh:
                json.dump(data, fh)
            proc = subprocess.run([sys.executable, CHECKER, path, "--label", "mutant %s" % name],
                                  capture_output=True, text=True)
            if proc.returncode != 1:
                print("FAIL: the evidence checker returned rc=%d (not 1) for mutant %r (%s) - "
                      "that property is NOT defended" % (proc.returncode, name, description))
                print(proc.stdout + proc.stderr)
                failures += 1
            else:
                print("  mutant %-18s -> rc=1 REJECTED  (%s)" % (name, description))
    finally:
        shutil.rmtree(work, ignore_errors=True)

    # The golden must be untouched: every mutant went to a throwaway copy.
    with open(golden_path, "r", encoding="utf-8") as fh:
        if fh.read() != original:
            print("FAIL: the stored golden CHANGED during the mutation run; mutants must only ever "
                  "be written to throwaway copies")
            failures += 1

    if failures:
        return 1
    print("PASS: all %d data mutants of the stored golden are REJECTED by the evidence checker, "
          "and the golden itself is byte-for-byte unchanged. Each mutant is exactly what a "
          "wrong-save or a dead run produces, so the gate is known to be able to go RED."
          % len(MUTANTS))
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2 or not os.path.isfile(sys.argv[1]):
        sys.stderr.write("usage: gate_013_mutants.py <state.json>\n")
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
