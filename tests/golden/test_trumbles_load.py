"""Offline falsifiability tests for scenario 015-trumbles (bead oo-hv4d). No game, no build.

WHAT THESE ARE FOR
------------------
The expensive half of this bead's gate launches the game. That is the only part that can observe
real engine behaviour and it is also the slowest thing on this box, so it is ONE acceptance line.
Everything falsifiable without a launch is falsified here, where it costs about a second and
cannot be defeated by machine load.

Each test builds a MUTANT that breaks exactly one property and asserts the guard goes red NAMING
the field. A guard nobody has watched fail is decoration.

TWO MUTANTS PER PROPERTY (bead oo-jor's lesson; oo-3ya's 13/15 -> 17/17). For every anti-vacuity
property this gate exists for there is a test that corrupts the DATA and a test that weakens the
CHECKER - only the second catches a gate that validates data with a validator nobody validates.

THE LAUNDERED RE-BLESS (bead oo-gxp's best mutant). Editing the golden alone is caught by
provenance's sha256; editing the golden AND its provenance consistently defeats that, and is
killed here by a CONTENT check - the evidence checker reading the laundered file and rejecting it
on what the numbers SAY, not on what they hash to.

The checker mutants write a COPY of the checker to a temp dir; the real file is NEVER touched -
restore-on-exit does not run when a process is killed at a timeout, and the orchestrator's gc can
harvest-and-commit the worktree at any instant.

NOTHING HERE WRITES TO goldens/ OR TO THE STAGED GOLDEN. The stored dump is READ, copied to a
throwaway temp file, and mutated there.
"""

import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SCENARIO = "015-trumbles"

# The golden, frame, spec and provenance live under tests/golden/pending/ until Jon approves the
# protected-path addition: tools/guardrails.sh refuses ANY change under goldens/ - CREATE as well
# as MODIFY - without a re-bless line in tools/rebless-approvals.txt. Both locations are searched
# so landing them is a pure `git mv` with no code change. See LANDING.md beside the artefacts.
GOLDEN_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "state.json"),
    os.path.join(HERE, "pending", SCENARIO, "state.json"),
)
FRAME_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "frame.grid"),
    os.path.join(HERE, "pending", SCENARIO, "frame.grid"),
)
SPEC_CANDIDATES = (
    os.path.join(HERE, "scenarios", SCENARIO, "spec.json"),
    os.path.join(HERE, "pending", SCENARIO, "spec.json"),
)
PROVENANCE_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "provenance.json"),
    os.path.join(HERE, "pending", SCENARIO, "provenance.json"),
)

EVIDENCE = os.path.join(HERE, "check_trumbles_evidence.py")
DIFF = os.path.join(HERE, "golden_diff.py")
SCRIPT = os.path.join(HERE, "trumbles_load.py")
SAVE = os.path.join(REPO_ROOT, "upstream", "oolite-tests", "Checklist-files", "Missions",
                    "Trumbles.oolite-save")

sys.path.insert(0, HERE)

import frame_hash  # noqa: E402
import trumbles_load  # noqa: E402


def _first(candidates, what):
    for path in candidates:
        if os.path.isfile(path):
            return path
    raise AssertionError("no %s; looked in %s" % (what, candidates))


GOLDEN = _first(GOLDEN_CANDIDATES, "stored golden")
FRAME = _first(FRAME_CANDIDATES, "stored reference frame grid")
SPEC = _first(SPEC_CANDIDATES, "spec.json")
PROVENANCE = _first(PROVENANCE_CANDIDATES, "provenance.json")


def run(script, *args):
    proc = subprocess.run([sys.executable, script] + list(args), capture_output=True, text=True,
                          cwd=REPO_ROOT)
    return proc.returncode, proc.stdout + proc.stderr


@pytest.fixture()
def golden():
    with open(GOLDEN, "r", encoding="utf-8") as handle:
        return json.load(handle)


@pytest.fixture()
def spec():
    with open(SPEC, "r", encoding="utf-8") as handle:
        return json.load(handle)


@pytest.fixture()
def provenance():
    with open(PROVENANCE, "r", encoding="utf-8") as handle:
        return json.load(handle)


@pytest.fixture()
def scratch():
    path = tempfile.mkdtemp(prefix="oo_hv4d_test_")
    yield path
    shutil.rmtree(path, ignore_errors=True)


def write(scratch, name, data):
    path = os.path.join(scratch, name)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(data, handle, sort_keys=True, separators=(",", ":"))
    return path


def mutated_checker(scratch, old, new, name="checker_mutant.py"):
    """A COPY of the evidence checker with one defence weakened. The real file is untouched."""
    with open(EVIDENCE, "r", encoding="utf-8") as handle:
        src = handle.read()
    assert old in src, "the checker no longer contains %r; this mutation is stale" % old
    path = os.path.join(scratch, name)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(src.replace(old, new, 1))
    return path


# --- the stored golden is itself real ---------------------------------------------------------

def test_the_stored_golden_proves_a_save_was_loaded():
    """The green direction. If this fails, every other test here measures a dead fixture."""
    rc, out = run(EVIDENCE, GOLDEN)
    assert rc == 0, out
    assert "EVIDENCE OK" in out, out


def test_the_stored_golden_is_not_a_fresh_commander(golden, spec):
    """Every field here is one a DEFAULT NEW GAME cannot produce."""
    ev = golden["evidence"]
    assert ev["load_stages"] == spec["load_progress_stages"], ev["load_stages"]
    assert sorted(ev["mission_variable_keys"]) == sorted(spec["expected_mission_variable_keys"])
    assert spec["mission_trumbles_key"] in ev["mission_variable_keys"], ev
    assert ev["save_written_by_version"] == "1.75", ev
    assert ev["round_trip_ok"] is True and ev["census_fields"] == len(spec["census"]), ev
    assert ev["cheat_messages"] == [] and ev["load_failures"] == [], ev


def test_the_stored_golden_is_a_real_world_state(golden):
    assert len(golden["entities"]) >= 1, golden["entities"]
    assert len(golden["market"]) >= 10, golden["market"]
    assert golden["player"]["ship"], golden["player"]


def test_the_stored_frame_grid_is_a_real_grid():
    """4096 bytes of luminance, not a stub. A near-flat grid carries no image and would compare
    within tolerance of any other flat grid, making the frame assertion decoration."""
    with open(FRAME, "rb") as handle:
        grid = handle.read()
    assert len(grid) == frame_hash.GRID_CELLS, len(grid)
    assert len(set(grid)) > 16, (
        "the stored frame grid has only %d distinct luminance values" % len(set(grid)))


# --- the determinism knobs are pinned, read, and witnessed by provenance -----------------------

def test_spec_pins_every_determinism_knob(spec):
    for key in ("seed", "system_id", "ticks", "tick_seconds", "quant_decimals", "load_save",
                "trumble_awards", "expected_trumble_count", "expected_saved_trumble_count",
                "log_channels", "load_progress_stages", "expected_mission_variable_keys",
                "repopulator_handlers", "census"):
        assert key in spec, "spec.json does not pin %r" % key
    assert spec["quant_decimals"] == 3, spec["quant_decimals"]
    assert isinstance(spec["ticks"], int) and spec["ticks"] >= 1, spec["ticks"]


def test_the_script_reads_every_knob_the_spec_pins():
    """A knob nobody reads is decoration, which is how a 'pinned' scenario silently drifts
    (bead oo-3ya: a seed that was PRINTED but had no predicate on it)."""
    with open(SCRIPT, encoding="utf-8") as handle:
        src = handle.read()
    for key in ("seed", "ticks", "tick_seconds", "system_id", "load_save", "trumble_awards",
                "expected_trumble_count", "expected_saved_trumble_count", "log_channels",
                "load_progress_stages", "expected_mission_variable_keys", "mission_trumbles_key",
                "repopulator_handlers", "census"):
        assert 'spec["%s"]' % key in src, "trumbles_load.py never reads spec[%r]" % key


def test_provenance_witnesses_the_golden_byte_for_byte(provenance):
    """THE INDEPENDENT WITNESS (bead oo-gxp). Perturbing state.json by one quantised unit leaves a
    golden-vs-copy comparison GREEN, because the mutation moves BOTH sides. provenance.json is a
    SEPARATE FILE the mutant does not touch."""
    blob = open(GOLDEN, "rb").read()
    rec = (provenance.get("artifacts") or {}).get("state.json")
    assert rec, "provenance records no artifacts.state.json digest"
    assert rec["bytes"] == len(blob), (rec["bytes"], len(blob))
    assert rec["sha256"] == hashlib.sha256(blob).hexdigest()


def test_provenance_records_the_knobs_the_golden_was_blessed_with(spec, provenance):
    """A fresh-run-vs-golden comparison CANNOT catch a changed seed, because changing the seed
    changes both sides. So the spec's knobs are asserted equal to the RECORDED ones."""
    knobs = provenance.get("scenario_knobs")
    assert knobs, "provenance records no scenario_knobs"
    for key in ("seed", "system_id", "ticks", "tick_seconds", "quant_decimals", "trumble_awards",
                "load_save"):
        assert key in knobs, "provenance scenario_knobs does not record %r" % key
        assert knobs[key] == spec[key], (key, knobs[key], spec[key])


def test_the_frame_grid_is_never_byte_hashed_into_the_verdict(provenance):
    """PRESERVE THE ASYMMETRY. The dump is quantised and deterministic, so it is hashed byte-wise.
    The frame is llvmpipe output and is NOT bit-reproducible, so it is compared with the measured
    tolerance. Provenance must record the grid's digest as a REFERENCE only, and the stability
    record must show the grids differing - otherwise someone has quietly started hashing it."""
    stab = provenance.get("stability") or {}
    assert stab.get("distinct_frame_grid_digests", 0) > 1, (
        "provenance claims the frame grids were identical across runs; if that is true the "
        "tolerance comparison is untested, and if it is not, the record is wrong: %r" % stab)
    tol = frame_hash.derive_tolerance()
    assert abs(tol - 0.004377268476873758) < 1e-12, (
        "frame_hash.TOLERANCE has moved from the value bead oo-ae9 measured (now %r); re-measure "
        "with calibrate.py, do NOT adjust it to make a run pass" % tol)


# --- the trumble determinism boundary is a MEASURED constant, not a preference ------------------

def test_the_award_count_is_the_measured_deterministic_prefix(spec):
    """PLAYER_MAX_TRUMBLES/6. PlayerEntity.m:11531's award gate takes its unconditional LEFT
    branch while trumbleCount < MAX/6; past that it consults ranrot_rand(), and a fixed seed pins
    the SEQUENCE but not how far a run has advanced through it (bead oo-izi's finding for
    system.addShips). Three runs at seed 20260918 agreed through four awards and diverged at the
    fifth. Raising this number makes the golden flaky."""
    assert spec["trumble_awards"] == trumbles_load.PLAYER_MAX_TRUMBLES // 6, spec["trumble_awards"]
    assert spec["expected_trumble_count"] == spec["trumble_awards"]


def test_the_savefile_checksum_uniquely_authorises_the_stored_count():
    """The fixture's trumble count is pinned by its own anti-cheat checksum, not by the integer
    it stores: PlayerEntity.m:12112-12125 SEARCHES 1..23 for a count matching the checksum when
    they disagree. Recomputing munge_checksum (legacy_random.c:48-57) over this commander's name,
    credits and kills must authorise exactly one count."""
    plist, _ = trumbles_load.read_save_file(SAVE)
    result = trumbles_load.verify_trumble_checksum(plist)
    assert result["counts_matching_checksum"] == [0], result
    assert result["checksum_authorises_stored_count"] is True, result
    assert result["stored_checksum"] == 20936, result


def test_the_save_is_the_1_75_trumbles_fixture():
    plist, size = trumbles_load.read_save_file(SAVE)
    assert str(plist["written_by_version"]) == "1.75", plist["written_by_version"]
    assert str(plist["player_name"]) == "Trumbles", plist["player_name"]
    assert "mission_trumbles" in plist["mission_variables"], plist["mission_variables"]
    assert size > trumbles_load.MIN_SAVE_BYTES, size


# --- DATA mutants: corrupt the golden, the gate must go red ------------------------------------

def test_a_golden_with_no_load_stages_is_rejected(golden, scratch):
    """The dead-run mutant: a run that ignored -load emits NO [load.progress] lines at all."""
    golden["evidence"]["load_stages"] = []
    rc, out = run(EVIDENCE, write(scratch, "no_stages.json", golden))
    assert rc == 1, out
    assert "load_stages" in out, out


def test_a_golden_with_a_truncated_load_is_rejected(golden, scratch):
    """The half-load mutant: the engine got to "Creating player ship" and stopped. rc=0 and an
    absence of errors would both still hold, which is the whole point."""
    golden["evidence"]["load_stages"] = golden["evidence"]["load_stages"][:3]
    rc, out = run(EVIDENCE, write(scratch, "partial.json", golden))
    assert rc == 1, out
    assert "load_stages" in out, out


def test_a_golden_with_no_mission_variables_is_rejected(golden, scratch):
    """The fresh-commander mutant: a default new game's mission variable dictionary is empty."""
    golden["evidence"]["mission_variable_keys"] = []
    golden["evidence"]["mission_variable_count"] = 0
    rc, out = run(EVIDENCE, write(scratch, "no_mv.json", golden))
    assert rc == 1, out
    assert "mission_variable" in out.lower(), out


def test_a_golden_missing_only_the_trumbles_mission_variable_is_rejected(golden, scratch):
    """NARROWER than the previous mutant on purpose: four of five keys survive, so the run looks
    loaded and only the field this bead is named for is gone."""
    keys = [k for k in golden["evidence"]["mission_variable_keys"] if k != "trumbles"]
    golden["evidence"]["mission_variable_keys"] = keys
    golden["evidence"]["mission_variable_count"] = len(keys)
    rc, out = run(EVIDENCE, write(scratch, "no_trumbles_mv.json", golden))
    assert rc == 1, out
    assert "trumbles" in out, out


def test_a_golden_with_a_mutated_trumble_count_is_rejected(golden, scratch):
    """THE POPULATION MUTANT the bead names."""
    golden["evidence"]["trumble_count"] = golden["evidence"]["trumble_count"] + 1
    rc, out = run(EVIDENCE, write(scratch, "count.json", golden))
    assert rc == 1, out
    assert "trumble_count" in out, out


def test_a_golden_whose_population_drifted_across_ticks_is_rejected(golden, scratch):
    """Breeding inside the tick budget would make the count a stopwatch reading."""
    golden["evidence"]["trumble_count_before_ticks"] = golden["evidence"]["trumble_count"] - 1
    golden["evidence"]["trumble_count_stable_across_ticks"] = False
    rc, out = run(EVIDENCE, write(scratch, "drift.json", golden))
    assert rc == 1, out
    assert "trumble_count_stable_across_ticks" in out or "moved from" in out, out


def test_a_golden_with_a_nondeterministic_award_count_is_rejected(golden, scratch):
    """Raising trumble_awards past PLAYER_MAX_TRUMBLES/6 buys a bigger population with a RANROT
    draw, which was MEASURED to differ between runs at the same seed."""
    golden["evidence"]["trumble_awards"] = 8
    golden["evidence"]["trumble_award_series"] = [1, 2, 3, 4, 5, 5, 6, 6]
    golden["evidence"]["trumble_count"] = 6
    golden["evidence"]["trumble_count_before_ticks"] = 6
    rc, out = run(EVIDENCE, write(scratch, "awards.json", golden))
    assert rc == 1, out
    assert "trumble_awards" in out, out


def test_a_golden_carrying_an_anticheat_message_is_rejected(golden, scratch):
    """If the engine had to SEARCH for a count matching the checksum, the loaded population is not
    the file's, and PlayerEntity.m:12106-12128 says so in the log."""
    golden["evidence"]["cheat_messages"] = ["POSSIBLE CHEAT DETECTED"]
    rc, out = run(EVIDENCE, write(scratch, "cheat.json", golden))
    assert rc == 1, out
    assert "cheat" in out.lower(), out


def test_a_golden_from_a_different_save_version_is_rejected(golden, scratch):
    """The 1.75 save-format contract this fixture pins."""
    golden["evidence"]["save_written_by_version"] = "1.90"
    rc, out = run(EVIDENCE, write(scratch, "version.json", golden))
    assert rc == 1, out
    assert "written_by_version" in out, out


def test_a_golden_whose_census_disagreed_is_rejected(golden, scratch):
    golden["evidence"]["round_trip_ok"] = False
    rc, out = run(EVIDENCE, write(scratch, "census.json", golden))
    assert rc == 1, out
    assert "round_trip_ok" in out, out


def test_a_golden_with_a_shrunken_census_is_rejected(golden, scratch):
    """A census of one trivially-equal field is the empty-state vacuity route in a smaller hat."""
    golden["evidence"]["census_fields"] = 2
    golden["evidence"]["round_trip_fields_equal"] = 2
    rc, out = run(EVIDENCE, write(scratch, "short_census.json", golden))
    assert rc == 1, out
    assert "census_fields" in out, out


def test_a_golden_with_no_evidence_block_is_rejected(golden, scratch):
    del golden["evidence"]
    rc, out = run(EVIDENCE, write(scratch, "bare.json", golden))
    assert rc == 1, out
    assert "evidence" in out, out


def test_an_empty_world_is_rejected(golden, scratch):
    golden["entities"] = []
    golden["market"] = {}
    rc, out = run(EVIDENCE, write(scratch, "empty.json", golden))
    assert rc == 1, out


def test_a_usage_error_is_distinguishable_from_a_verdict(scratch):
    """rc=2 means "I cannot tell you", never "they match" - golden_diff's convention (oo-ss8).
    A checker that returned 0 when it could not compare is the most dangerous failure mode."""
    rc, out = run(EVIDENCE, os.path.join(scratch, "does-not-exist.json"))
    assert rc == 2, out


# --- CHECKER mutants: weaken the validator, a known-bad input must STILL be rejected ------------
#
# Bead oo-jor shipped a gate whose DATA was protected but whose CHECKER was not: loosen the
# threshold and every test still passed. These are the other half of each pair above.

def test_weakening_the_load_stage_check_is_caught(golden, scratch):
    """EACH DEFENCE SEPARATELY. The first mutation removes the exact-sequence comparison; the
    property must STILL be held by the length/first/last clauses. MEASURED: an earlier version of
    this checker had only ONE defence here, and with it removed a dump carrying NO load stages was
    ACCEPTED (rc=0). That was a real blind gate, not an equivalent mutant, and the fix was to add
    the second defence rather than to delete the test."""
    bad = dict(golden)
    bad["evidence"] = dict(golden["evidence"], load_stages=[])
    path = write(scratch, "dead.json", bad)
    checker = mutated_checker(
        scratch,
        "if list(stages or []) != list(EXPECTED_LOAD_STAGES):",
        "if not list(stages or []) and False:")
    rc, out = run(checker, path)
    assert rc == 1, (
        "with the exact-sequence comparison removed the checker ACCEPTED a dump with NO load "
        "stages (rc=%d).\n%s" % (rc, out))


def test_the_second_load_stage_defence_alone_rejects_a_dead_run(golden, scratch):
    """The MIRROR of the test above: remove the length/first/last clauses instead, and the
    exact-sequence comparison must still reject the same input. Only running both directions
    proves the redundancy is real rather than two names for one check."""
    bad = dict(golden)
    bad["evidence"] = dict(golden["evidence"], load_stages=[])
    path = write(scratch, "dead2.json", bad)
    checker = mutated_checker(
        scratch,
        "if len(stages or []) != len(EXPECTED_LOAD_STAGES):",
        "if len(stages or []) != len(EXPECTED_LOAD_STAGES) and False:")
    rc, out = run(checker, path)
    assert rc == 1, (
        "with the length defence removed the checker ACCEPTED a dump with NO load stages "
        "(rc=%d).\n%s" % (rc, out))


def test_removing_both_load_stage_defences_flips_the_verdict(golden, scratch):
    """The mutation that GENUINELY changes behaviour, and the reason the two above are classified
    as redundancy rather than as holes. With every defence gone the dead run passes - so the
    property is real, it is held by two independent lines, and a future refactor that collapses
    them to one is caught by the two tests above."""
    bad = dict(golden)
    bad["evidence"] = dict(golden["evidence"], load_stages=[])
    path = write(scratch, "dead3.json", bad)
    src = open(EVIDENCE, encoding="utf-8").read()
    for old, new in (
            ("if list(stages or []) != list(EXPECTED_LOAD_STAGES):",
             "if list(stages or []) != list(EXPECTED_LOAD_STAGES) and False:"),
            ("if len(stages or []) != len(EXPECTED_LOAD_STAGES):",
             "if len(stages or []) != len(EXPECTED_LOAD_STAGES) and False:"),
            ("if not bounds_ok:", "if False and not bounds_ok:")):
        assert old in src, old
        src = src.replace(old, new, 1)
    checker = os.path.join(scratch, "no_load_defence.py")
    with open(checker, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(src)
    rc, out = run(checker, path)
    assert rc == 0, (
        "with ALL load-stage defences removed the dead run was STILL rejected (rc=%d), so the "
        "rejection is coming from somewhere else and the two tests above are not measuring what "
        "they claim.\n%s" % (rc, out))


def test_weakening_the_mission_variable_check_is_caught(golden, scratch):
    """The mutant compares mission variables by VALUE rather than by key set - which is exactly
    the mistake this scenario documents, because mission_trumbles is the EMPTY STRING and an
    absent variable reads the same. A fresh commander's EMPTY key set must still be rejected."""
    bad = dict(golden)
    bad["evidence"] = dict(golden["evidence"], mission_variable_keys=[], mission_variable_count=1)
    path = write(scratch, "novars.json", bad)
    checker = mutated_checker(
        scratch,
        "if keys != set(EXPECTED_MISSION_VARIABLE_KEYS):",
        "if keys - set(EXPECTED_MISSION_VARIABLE_KEYS):")
    rc, out = run(checker, path)
    assert rc == 1, (
        "with the key-set equality relaxed to a subset test the checker ACCEPTED a dump with NO "
        "mission variables (rc=%d) - a fresh commander would pass.\n%s" % (rc, out))


def test_weakening_the_trumble_count_check_is_caught(golden, scratch):
    """The mutant accepts any non-None count. The series-consistency defence must still reject a
    fabricated population. MEASURED: with only the direct equality, this mutant SURVIVED (rc=0,
    population 99 accepted) - a genuine blind gate, fixed by adding the second defence."""
    bad = dict(golden)
    bad["evidence"] = dict(golden["evidence"], trumble_count=99,
                           trumble_count_before_ticks=99)
    path = write(scratch, "bigcount.json", bad)
    checker = mutated_checker(
        scratch,
        'if ev.get("trumble_count") != awards:',
        'if ev.get("trumble_count") is None:')
    rc, out = run(checker, path)
    assert rc == 1, (
        "with the exact-count check relaxed the checker ACCEPTED a population of 99 after 4 "
        "awards (rc=%d).\n%s" % (rc, out))


def test_the_series_consistency_defence_alone_rejects_a_fabricated_count(golden, scratch):
    """The mirror: remove the series-consistency clauses instead; the direct equality must still
    reject the same input."""
    bad = dict(golden)
    bad["evidence"] = dict(golden["evidence"], trumble_count=99,
                           trumble_count_before_ticks=99)
    path = write(scratch, "bigcount2.json", bad)
    src = open(EVIDENCE, encoding="utf-8").read()
    for old, new in (
            ('if series and ev.get("trumble_count") != series[-1]:',
             'if False and series and ev.get("trumble_count") != series[-1]:'),
            ('if ev.get("trumble_count") != len(series):',
             'if False and ev.get("trumble_count") != len(series):')):
        assert old in src, old
        src = src.replace(old, new, 1)
    checker = os.path.join(scratch, "no_series_defence.py")
    with open(checker, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(src)
    rc, out = run(checker, path)
    assert rc == 1, (
        "with the series-consistency defence removed the checker ACCEPTED a population of 99 "
        "(rc=%d).\n%s" % (rc, out))


def test_weakening_the_award_series_check_is_caught(golden, scratch):
    """The mutant accepts any series of the right LENGTH. A series that skipped an award - the
    signature of the RANROT branch firing inside the supposedly deterministic prefix - must still
    be rejected."""
    bad = dict(golden)
    bad["evidence"] = dict(golden["evidence"], trumble_award_series=[1, 2, 2, 3],
                           trumble_count=3, trumble_count_before_ticks=3)
    path = write(scratch, "skipped.json", bad)
    checker = mutated_checker(
        scratch,
        "if series != list(range(1, awards + 1)):",
        "if len(series) != awards:")
    rc, out = run(checker, path)
    assert rc == 1, (
        "with the series compared only by LENGTH the checker ACCEPTED [1, 2, 2, 3] (rc=%d) - the "
        "exact signature of a RANROT draw firing inside the deterministic prefix.\n%s" % (rc, out))


def test_weakening_the_checksum_uniqueness_check_is_caught(golden, scratch):
    """The mutant relaxes the equality to a membership test. The cardinality defence must still
    reject an ambiguous checksum. MEASURED: with only the equality, this mutant SURVIVED (rc=0) -
    a genuine blind gate, fixed by adding the second defence."""
    bad = dict(golden)
    bad["evidence"] = dict(golden["evidence"], counts_matching_checksum=[0, 5, 11])
    path = write(scratch, "ambiguous.json", bad)
    checker = mutated_checker(
        scratch,
        "if list(ev.get(\"counts_matching_checksum\") or []) != [EXPECTED_SAVED_TRUMBLE_COUNT]:",
        "if EXPECTED_SAVED_TRUMBLE_COUNT not in (ev.get(\"counts_matching_checksum\") or []):")
    rc, out = run(checker, path)
    assert rc == 1, (
        "with the uniqueness requirement relaxed to membership the checker ACCEPTED a checksum "
        "authorising three different counts (rc=%d).\n%s" % (rc, out))


def test_the_cardinality_defence_alone_rejects_an_ambiguous_checksum(golden, scratch):
    """The mirror: remove the cardinality clause instead; the exact-list equality must still
    reject the same input."""
    bad = dict(golden)
    bad["evidence"] = dict(golden["evidence"], counts_matching_checksum=[0, 5, 11])
    path = write(scratch, "ambiguous2.json", bad)
    checker = mutated_checker(
        scratch,
        'if len(ev.get("counts_matching_checksum") or ()) != 1:',
        'if False and len(ev.get("counts_matching_checksum") or ()) != 1:')
    rc, out = run(checker, path)
    assert rc == 1, (
        "with the cardinality defence removed the checker ACCEPTED an ambiguous checksum "
        "(rc=%d).\n%s" % (rc, out))


# --- the golden_diff side: the comparison itself must be able to fail --------------------------

def test_golden_diff_refuses_to_compare_the_golden_with_itself():
    """A file always equals itself; zero differences from a self-comparison is not evidence."""
    rc, out = run(DIFF, GOLDEN, GOLDEN)
    assert rc == 2, out


def test_golden_diff_accepts_an_untouched_copy(scratch):
    copy = os.path.join(scratch, "copy.json")
    shutil.copyfile(GOLDEN, copy)
    rc, out = run(DIFF, GOLDEN, copy)
    assert rc == 0, out


def test_golden_diff_detects_one_quantised_unit(golden, scratch):
    """ONE quantised unit on one float. This is the mutant that defeated bead oo-gxp's comparison
    line when the line compared the golden against a copy of ITSELF."""
    copy = os.path.join(scratch, "nudged.json")
    shutil.copyfile(GOLDEN, copy)
    data = json.load(open(copy, encoding="utf-8"))
    data["player"]["credits"] = round(data["player"]["credits"] + 0.001, 3)
    with open(copy, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(data, handle, sort_keys=True, separators=(",", ":"))
    rc, out = run(DIFF, GOLDEN, copy)
    assert rc == 1, out
    assert "credits" in out, out


def test_a_laundered_rebless_is_caught_by_content(golden, scratch, provenance):
    """BEAD oo-gxp's BEST MUTANT: edit the golden AND its provenance CONSISTENTLY, so the sha256
    witness agrees and every hash check stays green. What kills it is a CONTENT check - the
    evidence checker judging what the numbers SAY, not what they hash to."""
    laundered = dict(golden)
    laundered["evidence"] = dict(golden["evidence"], trumble_count=7,
                                 trumble_count_before_ticks=7,
                                 trumble_award_series=[1, 2, 3, 4, 5, 6, 7], trumble_awards=7)
    path = write(scratch, "laundered.json", laundered)
    blob = open(path, "rb").read()
    prov = json.loads(json.dumps(provenance))
    prov["artifacts"]["state.json"] = {"bytes": len(blob),
                                       "sha256": hashlib.sha256(blob).hexdigest()}
    prov_path = write(scratch, "provenance.json", prov)

    # The witness now AGREES - the launder is complete.
    rec = json.load(open(prov_path, encoding="utf-8"))["artifacts"]["state.json"]
    assert rec["sha256"] == hashlib.sha256(open(path, "rb").read()).hexdigest()
    assert rec["bytes"] == os.path.getsize(path)

    # And the content check kills it anyway.
    rc, out = run(EVIDENCE, path)
    assert rc == 1, (
        "a LAUNDERED re-bless (golden and provenance edited consistently) was ACCEPTED (rc=%d). "
        "Hash witnesses alone cannot catch this; only a content check can.\n%s" % (rc, out))
    assert "trumble_awards" in out, out


# --- structural guards on the scenario script itself -------------------------------------------

def test_the_scenario_reserves_a_private_port_and_writes_the_plist():
    """The game DIALS OUT to the port in debugConfig.plist (OODebugSupport.m:67-80). On the shared
    8563 a sibling worker's console can capture and quit the game seconds in while the run still
    exits rc=0 - a fully vacuous pass (bead oo-het/oo-gla)."""
    src = open(SCRIPT, encoding="utf-8").read()
    assert "reserve_port" in src, "trumbles_load.py does not reserve a private console port"
    assert "_write_console_config" in src, "trumbles_load.py writes no debugConfig.plist"


def test_the_scenario_enables_the_engines_load_channels_via_a_staged_plist():
    """The load happens BEFORE the console connects, so the channels cannot be switched on from
    JS the way scenario 010 does with texture channels. They must come from a logcontrol.plist in
    a root path (ResourceManager.m:1761-1777)."""
    src = open(SCRIPT, encoding="utf-8").read()
    assert "enable_load_logging" in src, src[:200]
    assert "logcontrol.plist" in src


def test_the_scenario_passes_the_save_through_the_games_own_load_argument():
    """console.py:121-122 turns load_save= into `-load <path>`, which is the game's real
    deserialiser entry point (main.m:166-175 -> GameController.m:353)."""
    src = open(SCRIPT, encoding="utf-8").read()
    assert "load_save=save" in src, "trumbles_load.py does not pass the save to DebugConsole"


def test_the_stability_harness_records_every_run_regardless_of_exit_code():
    """A sibling harness recorded results only when returncode == 0 and so hid runs that wrote a
    correct dump but exited nonzero, reporting '1/10 dumped' when four byte-identical dumps
    existed."""
    src = open(SCRIPT, encoding="utf-8").read()
    assert "REFUSED" in src and "DUMPED" in src, "stability() does not distinguish the verdicts"
    assert "FEWER THAN TWO RUNS PRODUCED A DUMP" in src, (
        "stability() does not shout when there is nothing to compare")
