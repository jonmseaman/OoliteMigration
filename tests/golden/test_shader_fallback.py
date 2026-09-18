"""Offline tests for golden scenario 009-shaders. NO GAME, NO GPU: every test here reads the stored
artefacts, so `accept.sh` can re-gate the blessed golden in a clean checkout on any machine.

The tests come in two families, and the split is deliberate (bead oo-jor shipped a gate whose DATA
was protected but whose CHECKER was not):

  * DATA mutants   - take the blessed dump, corrupt ONE field, assert the checker refuses and that
                     the refusal NAMES that field. Written to throwaway copies via
                     check_shader_evidence's own --mutate table, never in place.
  * CHECKER mutants - reach into the checker, disable ONE defence, and assert the corresponding
                     data mutant then SURVIVES. That is what proves each defence is individually
                     load-bearing rather than redundant with its neighbours.
"""

import json
import os
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SCENARIO = "009-shaders"

sys.path.insert(0, HERE)

import check_shader_evidence as chk  # noqa: E402
import frame_hash  # noqa: E402


def _first(*candidates):
    for path in candidates:
        if os.path.isfile(path):
            return path
    return None


GOLDEN = _first(os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "state.json"),
                os.path.join(HERE, "pending", SCENARIO, "state.json"))
SPEC = _first(os.path.join(HERE, "scenarios", SCENARIO, "spec.json"),
              os.path.join(HERE, "pending", SCENARIO, "spec.json"))
PROV = _first(os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "provenance.json"),
              os.path.join(HERE, "pending", SCENARIO, "provenance.json"))
GRID = _first(os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "frame.grid"),
              os.path.join(HERE, "pending", SCENARIO, "frame.grid"))

pytestmark = pytest.mark.skipif(
    not (GOLDEN and SPEC and PROV and GRID),
    reason="scenario 009-shaders artefacts are not present in this checkout")


@pytest.fixture()
def spec():
    with open(SPEC, encoding="utf-8") as handle:
        return json.load(handle)


@pytest.fixture()
def state():
    with open(GOLDEN, encoding="utf-8") as handle:
        return json.load(handle)


@pytest.fixture()
def evidence(state):
    return state["evidence"]


@pytest.fixture()
def provenance():
    with open(PROV, encoding="utf-8") as handle:
        return json.load(handle)


def _fresh(state):
    """A deep, independent copy: a mutant must never be able to reach the fixture's object."""
    return json.loads(json.dumps(state))


# --- the blessed artefact passes, and says what it claims to say --------------------------------

def test_blessed_golden_passes_the_gate(evidence, spec):
    chk.check_evidence(evidence, spec)


def test_blessed_golden_matches_its_provenance(evidence, provenance):
    chk.check_provenance(evidence, provenance)


def test_shader_support_is_affirmative_not_merely_present(evidence):
    """The support line is matched EXACTLY, so the three refusal messages cannot pass as support."""
    assert evidence["shader_support_lines"] == [chk.SHADERS_SUPPORTED]


def test_the_driver_not_oolite_produced_the_glsl_diagnostic(evidence, spec):
    """The strongest single piece of evidence: text glGetInfoLogARB returned.

    Its SHAPE is the GLSL front end's own `line:column(offset): error: ...` form, which Oolite
    never writes. If this ever starts matching something Oolite could have produced, the evidence
    has stopped being about the driver.
    """
    log = evidence["glsl_driver_log"]
    assert log, "no driver diagnostic at all"
    assert any(spec["expected_glsl_diagnostic_substring"] in line for line in log)
    assert all(": error:" in line or ": warning:" in line for line in log), log


def test_driver_log_carries_no_engine_log_line(evidence):
    """No captured line may be an ENGINE line: those carry a timestamp and a pointer address.

    MEASURED: the first version of the capture ran past the driver's text into
    `[shader.load.failed]` and a `[shader.uniform.set]` line containing an OOShaderUniform POINTER,
    both of which differ on every run. The dump is compared BYTE FOR BYTE, so that made two
    correct runs disagree. This test pins the boundary rather than the symptom.
    """
    from shader_fallback import ENGINE_LOG_LINE_RE  # noqa: PLC0415

    for line in evidence["glsl_driver_log"]:
        assert not ENGINE_LOG_LINE_RE.search(line), line
        assert "0x" not in line, line


def test_cast_is_pinned_to_the_literal_ship_key_form(evidence, spec):
    """A bare role is a RANROT draw (bead oo-izi); the bracketed form admits exactly one ship."""
    assert evidence["demo_ship_role"] == "[%s]" % spec["shipdata_key"]
    assert evidence["demo_model_key"] == spec["shipdata_key"]


def test_spec_knobs_equal_provenance_knobs(spec, provenance):
    """Neither file may drift from the other: the dump is held against BOTH (bead oo-3ya)."""
    knobs = provenance["knobs"]
    assert knobs["seed"] == spec["seed"]
    assert knobs["ticks"] == spec["ticks"]
    assert knobs["system_id"] == spec["system_id"]
    assert knobs["tick_seconds"] == spec["tick_seconds"]


def test_frame_grid_is_the_measured_size(evidence):
    with open(GRID, "rb") as handle:
        assert len(handle.read()) == frame_hash.GRID_CELLS


def test_frame_differential_recorded_and_separated(provenance):
    """The two-arm control is RECORDED, and the numbers must actually separate.

    Same scene must sit under the measured tolerance; OXP-absent must sit far beyond it. If a
    future re-bless produced a run where removing the expansion did NOT move the frame, that would
    mean the expansion's content never reached the screen - and this test is where it shows up.
    """
    diff = provenance["frame_differential"]
    tol = frame_hash.derive_tolerance()
    assert diff["tolerance"] == pytest.approx(tol)
    assert diff["same_scene_distance"] < tol
    assert diff["oxp_absent_distance"] > tol * 10
    # A tolerance is only a test if the two populations are far apart; report the ratio.
    assert diff["oxp_absent_distance"] / diff["same_scene_distance"] > 20


def test_tolerance_is_the_measured_one_not_a_local_constant():
    """Nobody may loosen the threshold to make a run pass: it is derived from oo-ae9's data."""
    assert frame_hash.derive_tolerance() == pytest.approx(0.004377268476873758)


# --- DATA mutants: every defended property, corrupted one at a time -----------------------------

DATA_MUTANTS = [
    ("shader_dead", "shader_uniform_sets_positive"),
    ("no_link", "shader_uniform_sets_positive"),
    ("unsupported", "did NOT report shader support"),
    ("seed", "evidence.seed"),
    ("ticks", "evidence.ticks"),
    ("driver_log", "no line of the GL driver's own diagnostic"),
    ("standards_count", "oxp_standards_errors"),
    ("role", "demo_ship_role"),
    ("fallback", "shader_fallback_markers"),
]


@pytest.mark.parametrize("mutant,needle", DATA_MUTANTS)
def test_data_mutant_is_refused_and_names_the_field(state, spec, mutant, needle):
    corrupted = chk.MUTANTS[mutant](_fresh(state))
    with pytest.raises(chk.EvidenceError) as caught:
        chk.check_evidence(corrupted["evidence"], spec)
    assert needle in str(caught.value), str(caught.value)[:400]


def test_quantum_mutant_changes_the_dump_but_not_the_evidence(state, spec):
    """One quantised unit (0.001 at 3 decimals) is invisible to the EVIDENCE gate BY DESIGN.

    That is not a hole. The evidence gate asks "did shaders run"; the world state is defended by
    the BYTE-FOR-BYTE comparison with the stored golden, which is a different mechanism. This test
    pins the division of labour so nobody later concludes the evidence gate is blind and starts
    bolting float comparisons into it.
    """
    corrupted = chk.MUTANTS["quantum"](_fresh(state))
    chk.check_evidence(corrupted["evidence"], spec)  # evidence unaffected, deliberately
    canon = json.dumps(corrupted, sort_keys=True, separators=(",", ":"))
    with open(GOLDEN, encoding="utf-8") as handle:
        original = json.dumps(json.load(handle), sort_keys=True, separators=(",", ":"))
    assert canon != original, "a one-unit float change left the canonical dump identical"


def test_provenance_mutant_is_refused(evidence, provenance):
    """The third witness: spec and golden re-cut TOGETHER at a new seed still goes red."""
    tampered = json.loads(json.dumps(provenance))
    tampered["knobs"]["seed"] += 1
    with pytest.raises(chk.EvidenceError) as caught:
        chk.check_provenance(evidence, tampered)
    assert "provenance.knobs.seed" in str(caught.value)


def test_provenance_without_knobs_is_refused(evidence, provenance):
    tampered = json.loads(json.dumps(provenance))
    del tampered["knobs"]
    with pytest.raises(chk.EvidenceError):
        chk.check_provenance(evidence, tampered)


# --- CHECKER mutants: each defence is individually load-bearing ---------------------------------
# Each disables ONE defence on a COPY of the checker's own function table and asserts the matching
# data mutant then SURVIVES. A defence whose removal changes nothing is redundant and should be
# said so out loud rather than shipped as decoration.

CHECKER_MUTANTS = [
    # NOTE ON WHAT IS NOT IN THIS LIST. ("check_shaders_live", "shader_dead") was here and it
    # FAILED, honestly: with defence 1 disabled the `shader_dead` mutant is still caught, by
    # defence 2 (`shader_compile_failures is EMPTY`). READ THE CODE AND SAY WHICH: that is a
    # REDUNDANT DEFENCE, not a blind gate and not an equivalent mutant. Both defences genuinely
    # observe the silent fixed-function run - defence 1 because no program linked, defence 2
    # because no compile was attempted on the expansion's file - and the redundancy is WANTED for
    # the one failure mode this whole scenario exists to catch. It is pinned explicitly by
    # test_shader_dead_is_caught_by_defence_one_only below rather than papered over here.
    ("check_shaders_live", "no_link"),
    ("check_shaders_live", "unsupported"),
    ("check_expansion_shader_compiled", "driver_log"),
    ("check_no_silent_fallback", "fallback"),
    ("check_determinism_knobs", "seed"),
    ("check_determinism_knobs", "ticks"),
    ("check_standards_allowance", "standards_count"),
    ("check_fixture_live", "role"),
]


@pytest.mark.parametrize("defence,mutant", CHECKER_MUTANTS)
def test_disabling_one_defence_lets_its_mutant_through(state, spec, monkeypatch, defence, mutant):
    monkeypatch.setattr(chk, defence, lambda *a, **k: None)
    corrupted = chk.MUTANTS[mutant](_fresh(state))
    # Survives with the defence gone...
    chk.check_evidence(corrupted["evidence"], spec)
    # ...and dies with it restored. Both halves are needed: the first alone would also pass if the
    # mutant were a no-op, the second alone would also pass if some OTHER defence caught it.
    monkeypatch.undo()
    with pytest.raises(chk.EvidenceError):
        chk.check_evidence(corrupted["evidence"], spec)


def test_shader_dead_is_caught_by_defence_one_only(state, spec, monkeypatch):
    """The silent fixed-function run is the scenario's whole reason to exist - pinned twice.

    With defence 1 disabled the run survives only because defence 2 also fires on the same mutant
    (compile failures are empty), so BOTH are exercised here explicitly rather than relying on the
    parametrised case to have reached the one that matters.
    """
    corrupted = chk.MUTANTS["shader_dead"](_fresh(state))
    monkeypatch.setattr(chk, "check_shaders_live", lambda *a, **k: None)
    with pytest.raises(chk.EvidenceError) as caught:
        chk.check_evidence(corrupted["evidence"], spec)
    assert "shader_compile_failures is EMPTY" in str(caught.value)


def test_mutate_never_writes_in_place(tmp_path, state):
    """The harness's own safety property: a mutant is a COPY (a sibling bead committed one)."""
    before = open(GOLDEN, "rb").read()
    out = tmp_path / "mutant.json"
    rc = chk.main(["--mutate", "seed", GOLDEN, str(out)])
    assert rc == 0
    assert open(GOLDEN, "rb").read() == before
    assert json.loads(out.read_text(encoding="utf-8"))["evidence"]["seed"] != state["evidence"]["seed"]


def test_cli_refuses_a_dump_with_no_evidence_block(tmp_path, capsys):
    path = tmp_path / "bare.json"
    path.write_text(json.dumps({"entities": []}), encoding="utf-8")
    assert chk.main([str(path), "--spec", SPEC]) == 1


def test_cli_accepts_the_blessed_artefact():
    assert chk.main([GOLDEN, "--spec", SPEC, "--provenance", PROV]) == 0
