"""Offline: does this dump prove a 1.75 save round-tripped into the modern engine?

Reads a canonical dump written by tests/golden/cloaking_load.py and answers ONE question with no
game and no network: is the 1.75 save-format contract WITNESSED by this artifact, or is the
artifact merely well-shaped?

Run against the STORED GOLDEN it proves the golden is not vacuous, so a future byte-identical
comparison against it means something. Run against a FRESH RUN it re-checks the same properties
the capture-time gate checked, in code the capture path does not share - so a bug that disabled
the capture gate does not also disable this one.

rc CONVENTION (the repo's, deliberately): 0 = witnessed; 1 = a real failure; 2 = I cannot tell you
(unreadable, missing, malformed). A checker that returns 0 when it could not perform the
comparison is the most dangerous failure mode a gate can have.
"""

import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SCENARIO = "016-cloaking-save"

SPEC_CANDIDATES = (
    os.path.join(HERE, "scenarios", SCENARIO, "spec.json"),
    os.path.join(HERE, "pending", SCENARIO, "spec.json"),
)

# Fields whose ABSENCE makes every other clause unevaluable. A dump missing any of these is a
# REFUSAL (rc=2), not a failure: the question could not be asked.
REQUIRED_FIELDS = (
    "save_file", "save_bytes", "save_written_by_version",
    "census_equal", "census_equal_count", "census_differing", "census_detail", "census_fields",
    "mission_variable_keys_in_file", "mission_variable_keys_in_engine",
    "mission_variables_equal", "mission_variables_equal_count",
    "mission_variables_differing", "mission_variables_detail",
    "equipment_saved_count", "equipment_missing_in_engine", "equipment_live_only",
    "upgrade_log_lines", "world_at_rest", "world_reached_fixed_point", "tick_budget_met",
    "ticks", "seed", "system_id",
)


def spec_path():
    for path in SPEC_CANDIDATES:
        if os.path.isfile(path):
            return path
    raise SystemExit(2)


def load_spec():
    with open(spec_path(), "r", encoding="utf-8") as handle:
        return json.load(handle)


def _fail(message):
    raise Failure(message)


class Failure(RuntimeError):
    pass


class Unevaluable(RuntimeError):
    pass


def check(dump, spec, label):
    """Every clause names the specific failure it exists to catch (bead oo-9w5: a count floor is
    not a content check, so each defence is tied to a defect)."""
    if not isinstance(dump, dict):
        raise Unevaluable("%s is %r, not a JSON object" % (label, type(dump).__name__))
    ev = dump.get("evidence")
    if not isinstance(ev, dict):
        raise Unevaluable("%s carries no `evidence` block; there is nothing to witness" % label)
    missing = [k for k in REQUIRED_FIELDS if k not in ev]
    if missing:
        raise Unevaluable("%s is missing %d evidence field(s): %s. Without them the round-trip "
                          "question cannot be asked, let alone answered."
                          % (label, len(missing), ", ".join(missing)))

    notes = []

    # --- 1. IT IS THE RIGHT FIXTURE, AND IT IS THE ERA THE CONTRACT IS ABOUT -----------------
    want_save = os.path.basename(spec["load_save"])
    if ev["save_file"] != want_save:
        _fail("%s was produced from %r, not the %r this scenario pins. A round-trip result about "
              "a different file is not this scenario's result." % (label, ev["save_file"], want_save))
    if str(ev["save_written_by_version"]) != str(spec["save_format_version"]):
        _fail("%s reports written_by_version=%r, not the %r-era format whose compatibility this "
              "scenario is the contract for."
              % (label, ev["save_written_by_version"], spec["save_format_version"]))
    if int(ev["save_bytes"]) < 1024:
        _fail("%s records a %d-byte save; a stub parses to few keys and every comparison against "
              "it is vacuous however green." % (label, int(ev["save_bytes"])))

    # --- 2. MISSION VARIABLE PRESENCE, WITNESSED AS A KEY SET --------------------------------
    # A MISSION VARIABLE THAT IS THE EMPTY STRING READS IDENTICALLY TO AN ABSENT ONE, so the key
    # set is checked on its own and never inferred from the value comparison. A default new game's
    # dictionary is EMPTY (PlayerEntity.m:1986-1987), which is what a run that ignored -load
    # cannot fake.
    want_keys = sorted(spec["expected_mission_variable_keys"])
    for side in ("mission_variable_keys_in_file", "mission_variable_keys_in_engine"):
        if sorted(ev[side]) != want_keys:
            _fail("%s: %s is %r, not the %d key(s) this save carries. A FRESH COMMANDER HAS NONE, "
                  "so this set is the presence proof a dead or unloaded run cannot produce."
                  % (label, side, ev[side], len(want_keys)))
    if not ev["mission_variable_keys_in_file"]:
        _fail("%s witnesses an EMPTY mission variable key set; an empty set is a subset of every "
              "other and proves nothing about a load." % label)

    # --- 3. THE CLOSED PAIR, BOTH SIDES ------------------------------------------------------
    for name, diffkey, detailkey, declared in (
            ("mission variables", "mission_variables_differing", "mission_variables_detail",
             spec["mission_variable_write_exceptions"]),
            ("census fields", "census_differing", "census_detail", spec["census_migrations"])):
        got = sorted(ev[diffkey])
        want = sorted(declared)
        if got != want:
            _fail("%s: the %s that differ between file and engine are %r, but this scenario "
                  "declares exactly %r. UNDECLARED: %r (a field that stopped round-tripping - the "
                  "save-format regression this scenario exists to catch). DECLARED BUT ABSENT: "
                  "%r (a migration the engine is documented to perform stopped happening). "
                  "Neither list may be edited to make this pass."
                  % (label, name, got, want, sorted(set(got) - set(want)),
                     sorted(set(want) - set(got))))
        for key, rule in declared.items():
            det = ev[detailkey].get(key)
            if not isinstance(det, dict) or "in_file" not in det or "in_engine" not in det:
                raise Unevaluable("%s: %s detail for %r is %r, with no in_file/in_engine pair to "
                                  "check the delta against" % (label, name, key, det))
            delta = round(float(det["in_engine"]) - float(det["in_file"]), 3)
            if delta != round(float(rule["delta"]), 3):
                _fail("%s: %s reads %r on disk and %r in the engine, a delta of %r, but %r is "
                      "pinned. EQUAL VALUES ARE THE DESERIALISER-COPY SIGNATURE and any other "
                      "delta means the migration changed."
                      % (label, key, det["in_file"], det["in_engine"], delta, rule["delta"]))
            notes.append("%s %s: %s -> %s (%+g, declared)"
                         % (name[:-1], key, det["in_file"], det["in_engine"], delta))

    # --- 4. THE FLOORS: the exact-set clause must not be satisfiable by a near-empty census ---
    if int(ev["mission_variables_equal_count"]) < int(spec["min_mission_variables_round_tripped"]):
        _fail("%s witnesses only %d mission variable(s) round-tripping unchanged, under the floor "
              "of %d." % (label, ev["mission_variables_equal_count"],
                          spec["min_mission_variables_round_tripped"]))
    if int(ev["census_equal_count"]) < int(spec["min_census_fields_round_tripped"]):
        _fail("%s witnesses only %d census field(s) round-tripping unchanged, under the floor of "
              "%d." % (label, ev["census_equal_count"], spec["min_census_fields_round_tripped"]))
    if int(ev["census_fields"]) != len(spec["census"]):
        _fail("%s compared %d census field(s) but the spec declares %d; a shrunken census is the "
              "vacuity route wearing a smaller hat."
              % (label, ev["census_fields"], len(spec["census"])))

    # --- 5. EQUIPMENT: containment minus declared removals, plus the ENGINE'S OWN TESTIMONY --
    removals = {k for k, v in spec["equipment_migrations"].items()
                if v["disposition"] == "REMOVED"}
    unexplained = sorted(set(ev["equipment_missing_in_engine"]) - removals)
    if unexplained:
        _fail("%s: the live ship was missing %r, which this scenario does not declare a migration "
              "for. extra_equipment is the 1.75 format's equipment record." % (label, unexplained))
    still = sorted(removals - set(ev["equipment_missing_in_engine"]))
    if still:
        _fail("%s: %r are declared REMOVED by the loader's legacy migration but the live ship "
              "still carried them; the declared migration stopped happening." % (label, still))
    if int(ev["equipment_saved_count"]) != int(spec["expected_equipment_count"]):
        _fail("%s: the save's extra_equipment carried %d key(s), not the %d pinned; the "
              "containment assertion would be measuring a different save."
              % (label, ev["equipment_saved_count"], spec["expected_equipment_count"]))
    # THE INDEPENDENT WITNESS FOR THE CREDIT DELTA. Without it the +900 is arithmetic that happens
    # to add up; with it, the loader itself says which compensation branch it took.
    text = "\n".join(ev["upgrade_log_lines"])
    for key, rule in spec["equipment_migrations"].items():
        if rule["disposition"] != "REMOVED":
            continue
        if rule["compensation_log_substring"] not in text:
            _fail("%s carries no %r line on the %s channel. The engine's own testimony is what "
                  "turns the credits delta into PROOF of the compensation branch; lines seen: %r"
                  % (label, rule["compensation_log_substring"],
                     rule["compensation_log_channel"], ev["upgrade_log_lines"]))

    # --- 6. THE DUMP MUST CARRY THE MISSION STATE AT TOP LEVEL, BY NAME ----------------------
    top = dump.get("mission_variables")
    if not isinstance(top, dict) or not top:
        _fail("%s carries no top-level `mission_variables`; the bead requires the canonical dump "
              "itself to carry mission state, in particular mission_cloakcounter." % label)
    for key in want_keys:
        if key not in top:
            _fail("%s's top-level mission_variables is missing %r; the dump must carry the FILE's "
                  "own key names so a future diff sees the format's fields by name."
                  % (label, key))

    # --- 7. THE RUN WAS A REAL, SETTLED, BUDGETED RUN ---------------------------------------
    for key in ("world_at_rest", "world_reached_fixed_point", "tick_budget_met"):
        if not ev[key]:
            _fail("%s reports %s=false; the dump's values would be frame-count dependent or the "
                  "state is not the one the spec describes." % (label, key))
    for key, want in (("ticks", spec["ticks"]), ("seed", spec["seed"]),
                      ("system_id", spec["system_id"])):
        if ev[key] != want:
            _fail("%s was produced at %s=%r but the spec pins %r; the artifact and the spec "
                  "describe different runs." % (label, key, ev[key], want))

    # --- 8. NO FRAME DIGEST INSIDE THE DUMP -------------------------------------------------
    blob = json.dumps(dump, sort_keys=True)
    if "frame_hash" in blob or "frame_grid" in blob:
        _fail("%s carries a frame digest. llvmpipe is NOT bit-reproducible across runs, so a "
              "frame hash inside the canonical dump makes the byte-identical golden comparison "
              "flake on renderer noise. Frames live beside the dump as frame.grid and are "
              "compared with the MEASURED tolerance." % label)

    return notes


def main(argv=None):
    parser = argparse.ArgumentParser(prog="tests/golden/check_cloaking_evidence.py",
                                     description=__doc__.split("\n")[0])
    parser.add_argument("dump")
    parser.add_argument("--label", default=None)
    args = parser.parse_args(argv)
    label = args.label or args.dump

    try:
        spec = load_spec()
    except (OSError, ValueError) as exc:
        sys.stderr.write("REFUSED: cannot read the scenario spec: %s\n" % exc)
        return 2
    try:
        with open(args.dump, "r", encoding="utf-8") as handle:
            dump = json.load(handle)
    except (OSError, ValueError) as exc:
        sys.stderr.write("REFUSED: cannot read %s: %s\n" % (label, exc))
        return 2

    try:
        notes = check(dump, spec, label)
    except Unevaluable as exc:
        sys.stderr.write("REFUSED: %s\n" % exc)
        return 2
    except Failure as exc:
        sys.stderr.write("FAIL: %s\n" % exc)
        return 1

    ev = dump["evidence"]
    print("OK: %s witnesses a %s-era save round-tripping into the live engine - %d/%d census "
          "field(s) and %d/%d mission variable(s) identical across two independent readers, all "
          "%d saved equipment key(s) accounted for, and the ONLY differences are the declared "
          "migrations:"
          % (label, ev["save_written_by_version"], ev["census_equal_count"], ev["census_fields"],
             ev["mission_variables_equal_count"], len(ev["mission_variable_keys_in_file"]),
             ev["equipment_saved_count"]))
    for note in notes:
        print("  %s" % note)
    print("  equipment EQ_ENERGY_BOMB: removed, engine testimony %r" % (ev["upgrade_log_lines"],))
    return 0


if __name__ == "__main__":
    sys.exit(main())
