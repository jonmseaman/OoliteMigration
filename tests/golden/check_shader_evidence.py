"""The offline gate for scenario 009-shaders: re-check a STORED dump with no game running.

WHY THIS IS A SEPARATE MODULE. The predicates must be runnable against `state.json` alone, on a
machine with no build and no GPU, so that `accept.sh` can re-gate the blessed artefact in a clean
checkout. Keeping them here (rather than inline in `shader_fallback.py`) is also what lets the
mutation harness attack the CHECKER and the DATA separately - bead oo-jor shipped a gate whose data
was protected but whose checker was not.

THE CENTRAL QUESTION THIS GATE ANSWERS is not "did the run finish" but "DID GLSL ACTUALLY EXECUTE".
On a renderer without shader support Oolite renders everything with fixed function, logs one line
about it at startup and then says NOTHING further; the dump is clean, the frame is a real frame,
and rc=0. Four independent defences below make that state impossible to pass off as success, and
each names the ENGINE-EMITTED field it rests on.
"""

import argparse
import json
import os
import re
import sys


class EvidenceError(AssertionError):
    pass


# OOOpenGLExtensionManager.m:289 is the ONLY affirmative message on this channel; :280, :572 and
# :592 are the three refusals ("disallowed for GPU type", "disabled on command line", "OpenGL
# extension %@ is not available"). Matching the affirmative EXACTLY means any refusal fails.
SHADERS_SUPPORTED = "Shaders are supported."

# The engine never writes the renderer string itself - it is glGetString(GL_RENDERER) echoed back -
# so a line matching this shape is proof a GL context was created and interrogated.
GL_VERSION_SHAPE = re.compile(
    r"OpenGL renderer version: \S+ \(\".*\"\)\. Vendor: \".*\"\. Renderer: \".*\"\.")


def _require(condition, message):
    if not condition:
        raise EvidenceError(message)


def check_shaders_live(evidence):
    """DEFENCE 1: GLSL is live on this renderer, and REAL PROGRAMS LINKED.

    Two separate facts, because the first alone is not enough. The support line says the extensions
    are present; it does not say a program was ever built. `shader_uniform_sets_positive` does:
    `[shader.uniform.set]` is emitted from OOShaderMaterial -initWithName:... (OOShaderMaterial.m:
    327 and five sibling sites), reached only after `OK = (shaderProgram != nil)` at :236 - i.e.
    only once glCompileShaderARB and glLinkProgramARB have BOTH returned GL_TRUE
    (OOShaderProgram.m:322, :337, :353, validated at :261-267).

    WHY A DEAD RUN CANNOT SATISFY THIS: a fixed-function run builds OOSingleTextureMaterial /
    OOBasicMaterial instead (OOMaterialConvenienceCreators.m:324-338), which contain no uniforms
    and emit no such line. The field is therefore false exactly when nothing was shaded.
    """
    support = evidence.get("shader_support_lines") or []
    _require(support,
             "evidence.shader_support_lines is EMPTY: the run logged nothing on "
             "[rendering.opengl.shader.support], so nothing establishes whether this renderer can "
             "run GLSL at all. That line is emitted unconditionally by "
             "OOOpenGLExtensionManager.m (one of :280/:289/:572/:592) on every launch, so its "
             "absence means the log was never read - not that shaders are fine.")
    bad = [line for line in support if line != SHADERS_SUPPORTED]
    _require(not bad,
             "the engine did NOT report shader support: %r. The only affirmative message on that "
             "channel is %r (OOOpenGLExtensionManager.m:289); the alternatives are 'disallowed for "
             "GPU type' (:280), 'disabled on command line' (:572) and 'OpenGL extension ... is not "
             "available' (:592), each of which means the engine fell back to FIXED FUNCTION and "
             "rendered the frame without running one line of GLSL. This scenario is about shaders; "
             "a golden taken in that state tests nothing it claims to."
             % (bad, SHADERS_SUPPORTED))

    renderers = evidence.get("gl_renderer_lines") or []
    _require(renderers,
             "evidence.gl_renderer_lines is EMPTY: nothing records WHICH renderer this golden was "
             "taken against, so the shader evidence cannot be attributed to a GL implementation.")
    _require(all(GL_VERSION_SHAPE.search(line) for line in renderers),
             "a [rendering.opengl.version] line does not carry a renderer string: %r. The vendor "
             "and renderer names are glGetString() output echoed by the engine, so a line without "
             "them means no GL context was interrogated." % (renderers,))

    _require(evidence.get("shader_uniform_sets_positive") is True,
             "evidence.shader_uniform_sets_positive is not true: NOT ONE [shader.uniform.set] line "
             "was emitted, so no OOShaderMaterial ever finished building. That line comes from "
             "OOShaderMaterial.m:327 (and five siblings), reached only after `OK = (shaderProgram "
             "!= nil)` at :236 - i.e. only once glCompileShaderARB AND glLinkProgramARB both "
             "returned GL_TRUE. A run that rendered with fixed function emits none of them and is "
             "otherwise indistinguishable from this one: clean log, real frame, rc=0. THIS IS THE "
             "FIELD THAT MAKES THAT STATE FAIL.")


def check_expansion_shader_compiled(evidence, spec):
    """DEFENCE 2: THE EXPANSION'S OWN shader source reached the GL driver's compiler.

    Defence 1 proves GLSL runs; it says nothing about the expansion, because the engine's own
    built-in shaders would satisfy it on a stock game. This defence pins the evidence to the
    fixture's file by name, and to the DRIVER'S OWN DIAGNOSTIC TEXT.

    WHY A DEAD RUN CANNOT SATISFY IT: `glsl_driver_log` is read back out of the GL implementation
    by GetGLSLInfoLog (OOShaderProgram.m:481, glGetInfoLogARB), so its wording is Mesa's GLSL front
    end reporting on bytes handed to it by glShaderSourceARB (:335). Oolite cannot synthesise that
    text. If the OXP were rejected, or shaders were off, the compile is never attempted and the
    list is empty - which is exactly what the OXP-ABSENT control arm measured.
    """
    shader = spec["expected_fragment_shader"]
    failures = evidence.get("shader_compile_failures") or []
    _require(failures,
             "evidence.shader_compile_failures is EMPTY. This fixture's fragment shader %r "
             "contains a DELIBERATE syntax error (its own comment says so), so a run in which the "
             "expansion's material was built MUST produce a [shader.compile.failure]. An empty "
             "list means the shader source never reached the GL compiler - because the expansion "
             "was not loaded, because the material was never built, or because the engine rendered "
             "with fixed function. Removing this predicate would make the scenario green on all "
             "three." % shader)
    named = [f for f in failures if f.get("shader") == shader]
    _require(named,
             "no [shader.compile.failure] named %r; the failures seen were %r. The evidence must "
             "be about THIS expansion's shader and no other - the engine's own shaders failing "
             "would be a different (and much worse) finding." % (shader, failures))
    _require(all(f.get("stage") == "compile" for f in named),
             "a failure for %r is not at the COMPILE stage: %r. The fixture's defect is a syntax "
             "error, which glCompileShaderARB rejects (OOShaderProgram.m:322/:337); a LINK-stage "
             "failure would mean something else entirely went wrong." % (shader, named))

    driver_log = evidence.get("glsl_driver_log") or []
    _require(driver_log,
             "evidence.glsl_driver_log is EMPTY. That text is read back out of the GL "
             "implementation by GetGLSLInfoLog (OOShaderProgram.m:481, glGetInfoLogARB) and is the "
             "single strongest piece of evidence in this scenario: the DRIVER describing the "
             "expansion's own source bytes. Oolite does not write it and cannot fabricate it.")
    needle = spec["expected_glsl_diagnostic_substring"]
    _require(any(needle in line for line in driver_log),
             "no line of the GL driver's own diagnostic contains %r; it reads %r. The fixture's "
             "fragment shader body is `this is a syntax error;`, so a GLSL front end that actually "
             "parsed those bytes must object to them. A different complaint means the driver was "
             "given different source." % (needle, driver_log))

    load_failures = evidence.get("shader_load_failures") or []
    expected_pair = "%s/%s" % (spec["expected_vertex_shader"], shader)
    _require(expected_pair in load_failures,
             "evidence.shader_load_failures does not contain %r (it holds %r). "
             "OOShaderMaterial.m:228 logs that pair once the program could not be built, which is "
             "the engine CONFIRMING - separately from the driver - that this expansion's material "
             "did not get a shader." % (expected_pair, load_failures))


def check_no_silent_fallback(evidence):
    """DEFENCE 3: the engine did NOT take a reduced-complexity fallback behind our back.

    The fixture was written for r3144-era Oolite, whose fallback would have recompiled the shader
    with OO_REDUCED_COMPLEXITY and produced a DIFFERENT, SUCCESSFUL program. That path is disabled
    in the source today: the entire block sits inside `#if 0` (OOShaderMaterial.m:191-224, comment
    "no reduced complexity mode now"), so `shader.load.fullModeFailed` and
    `shader.load.fallbackSuccess` cannot be emitted.

    Asserting their ABSENCE is not decoration: if the fallback is ever re-enabled upstream, this
    scenario's whole observable changes (the cube would be shaded green instead of unshaded red,
    and `shader_load_failures` would be empty) and this line is the one that goes red first,
    naming the marker that appeared.
    """
    markers = evidence.get("shader_fallback_markers")
    _require(markers == [],
             "evidence.shader_fallback_markers is %r, not []. The reduced-complexity fallback is "
             "compiled out (OOShaderMaterial.m:191-224 is inside `#if 0`), so these markers cannot "
             "occur on this engine. Their presence means the fallback was re-enabled upstream and "
             "this scenario is now measuring different behaviour than it was blessed against - "
             "re-derive it, do not delete this check." % (markers,))


def check_fixture_live(evidence, spec):
    """DEFENCE 4: the fixture's content is live in the ENGINE, and the cube on screen is ITS cube.

    `shipdata` is read back from `Ship.shipDataForKey` (OOJSShip.m:578), the MERGED registry, so it
    resolving proves the expansion's Config/shipdata.plist was parsed and merged. `demo_model_key`
    is `mission.displayModel.dataKey` read off the ship the engine actually instantiated, so it
    proves the object on screen came from that entry rather than from a role draw landing elsewhere
    (bead oo-izi).
    """
    _require(evidence.get("oxp_staged") is True,
             "evidence.oxp_staged is false: nothing was staged, so this run says nothing about the "
             "expansion")

    shipdata = evidence.get("shipdata") or {}
    _require(shipdata.get("fragment_shader") == spec["expected_fragment_shader"],
             "evidence.shipdata.fragment_shader is %r but the spec pins %r. This string is read "
             "back out of the RUNNING engine's merged ship registry and names the file the engine "
             "will hand to the GL compiler; a mismatch means the registry is not this fixture's."
             % (shipdata.get("fragment_shader"), spec["expected_fragment_shader"]))
    _require(shipdata.get("vertex_shader") == spec["expected_vertex_shader"],
             "evidence.shipdata.vertex_shader is %r but the spec pins %r"
             % (shipdata.get("vertex_shader"), spec["expected_vertex_shader"]))
    _require(shipdata.get("name") == spec["expected_ship_name"],
             "evidence.shipdata.name is %r but the spec pins %r"
             % (shipdata.get("name"), spec["expected_ship_name"]))

    _require(evidence.get("demo_model_key") == spec["shipdata_key"],
             "evidence.demo_model_key is %r but the scenario pins the cube to %r. The role is "
             "asked for in the LITERAL `[shipKey]` form, which OOShipRegistry.m:1229 registers at "
             "probability 1.0 and which therefore admits exactly one ship class; a bare role is a "
             "RANROT draw whose outcome a fixed seed does NOT fix (bead oo-izi: Universe.m:4008 -> "
             ":3948 -> OOShipRegistry.m:276-279). A different key here means the cast moved and no "
             "two runs can agree." % (evidence.get("demo_model_key"), spec["shipdata_key"]))
    _require(evidence.get("demo_model_name") == spec["expected_ship_name"],
             "evidence.demo_model_name is %r but the spec pins %r"
             % (evidence.get("demo_model_name"), spec["expected_ship_name"]))
    _require(evidence.get("demo_ship_role") == spec["demo_ship_role"],
             "evidence.demo_ship_role is %r but the spec pins %r; the bracketed form IS the "
             "determinism pin and a run that asked for something else is not comparable"
             % (evidence.get("demo_ship_role"), spec["demo_ship_role"]))
    _require(evidence.get("gui_screen") == "GUI_SCREEN_MISSION",
             "evidence.gui_screen is %r: the frame was not taken on the mission screen carrying "
             "the expansion's cube" % (evidence.get("gui_screen"),))


def check_determinism_knobs(evidence, spec):
    """DEFENCE 5: every knob the run read is the knob the spec pins, and the run really ran.

    BEAD oo-3ya'S LESSON, APPLIED. A spec that merely PRINTS its seed has no predicate on it, and a
    fresh-run-vs-golden comparison cannot catch a changed seed because changing it changes BOTH
    sides. So each knob is compared with the value RECORDED IN THE DUMP: change the spec's seed and
    the stored golden goes red; change both and `--provenance` (below) goes red.
    """
    _require(evidence.get("seed") == int(spec["seed"]),
             "evidence.seed is %r but the spec pins %r. A golden taken at a different seed is a "
             "different experiment." % (evidence.get("seed"), spec["seed"]))
    _require(evidence.get("ticks") == int(spec["ticks"]),
             "evidence.ticks is %r but the spec pins %r" % (evidence.get("ticks"), spec["ticks"]))
    _require(evidence.get("system_id") == int(spec["system_id"]),
             "evidence.system_id is %r but the spec pins %r"
             % (evidence.get("system_id"), spec["system_id"]))
    _require(evidence.get("detail_level") in spec["shader_capable_detail_levels"],
             "evidence.detail_level is %r, not one of the shader-capable levels %r. "
             "Universe -useShaders is `detailLevel >= DETAIL_LEVEL_SHADERS` (Universe.m:10083); "
             "below it every shader material is skipped SILENTLY "
             "(OOMaterialConvenienceCreators.m:278)."
             % (evidence.get("detail_level"), spec["shader_capable_detail_levels"]))
    _require(evidence.get("game_seconds_budget")
             == round(int(spec["ticks"]) * float(spec["tick_seconds"]), 3),
             "evidence.game_seconds_budget is %r but ticks*tick_seconds is %r; the tick LENGTH is "
             "a knob too and this is the only line that can see it change"
             % (evidence.get("game_seconds_budget"),
                round(int(spec["ticks"]) * float(spec["tick_seconds"]), 3)))
    _require(evidence.get("tick_budget_met") is True,
             "evidence.tick_budget_met is false: the game clock advanced less than the scenario's "
             "budget of %s game seconds, so the simulation did not run"
             % evidence.get("game_seconds_budget"))
    _require(evidence.get("world_at_rest") is True,
             "evidence.world_at_rest is false: the world was still integrating when the frame and "
             "the dump were taken")
    _require(evidence.get("world_reached_fixed_point") is True,
             "evidence.world_reached_fixed_point is false: the clearing loop never saw a round "
             "that both removed nothing and left nothing, so something was still adding entities")
    _require(evidence.get("populators_suppressed"),
             "evidence.populators_suppressed is 0: the system populator was never switched off")
    _require(evidence.get("stations_quieted"),
             "evidence.stations_quieted is 0: no station had hasNPCTraffic written false; "
             "StationEntity -update (StationEntity.m:960-995) runs its own launch schedule")
    _require(sorted(evidence.get("repopulator_handlers_quieted") or [])
             == sorted(spec["repopulator_handlers"]),
             "evidence.repopulator_handlers_quieted is %r but the spec pins %r; "
             "oolite-populator.js's systemWillRepopulate keeps launching traffic for the life of "
             "the system and its station picker ends with an unconditional `return "
             "system.mainStation`, so hasNPCTraffic does not stop it"
             % (sorted(evidence.get("repopulator_handlers_quieted") or []),
                sorted(spec["repopulator_handlers"])))
    _require(sorted(evidence.get("shader_log_channels") or [])
             == sorted(spec["shader_log_channels"]),
             "evidence.shader_log_channels is %r but the spec pins %r. `shader.uniform` is OFF by "
             "default ($shaderDebugOn = no, logcontrol.plist:37,:336), so a run that did not "
             "switch it on would see zero uniform lines and could not tell 'not logged' from 'no "
             "shader ran'." % (sorted(evidence.get("shader_log_channels") or []),
                               sorted(spec["shader_log_channels"])))


def check_standards_allowance(evidence, spec):
    """DEFENCE 6: the NOMANIF allowance, held EXACTLY (bead oo-kcrw; mechanism bead oo-dto).

    `Fallback test.oxp` predates the manifest format. ResourceManager.m:636-664 branches on the
    FILE EXTENSION: an `.oxz` with no manifest RETURNS at :640 and is never added to searchPaths,
    while an `.oxp` emits OOStandardsError at :646 and - unless OOEnforceStandards() - falls
    through to :654 where a basic manifest is SYNTHESISED and the path added at :663. So this
    fixture LOADS, and emits exactly two of those lines.

    The allowance is a PIN, not a relaxation: a third line, or any different [oxp-standards.error],
    fails. `--stage-double` proves the count predicate fires.
    """
    allowed_count = int(spec["allowed_oxp_standards_errors"])
    allowed = set(spec["allowed_oxp_standards_error_signatures"])
    _require(evidence.get("oxp_standards_errors") == allowed_count,
             "evidence.oxp_standards_errors is %r but exactly %d is allowed for this fixture. A "
             "different count means a NEW problem, and widening this number to make a run pass is "
             "forbidden. Signatures seen: %r"
             % (evidence.get("oxp_standards_errors"), allowed_count,
                evidence.get("oxp_standards_error_signatures")))
    unexpected = [s for s in (evidence.get("oxp_standards_error_signatures") or [])
                  if s not in allowed]
    _require(not unexpected,
             "the run emitted an [oxp-standards.error] line that is NOT the known "
             "missing-manifest message: %r. The allow-list is %r and it is deliberately exact."
             % (unexpected, sorted(allowed)))


def check_evidence(evidence, spec):
    """Every defence, in order. Raises EvidenceError naming the field and both values."""
    check_shaders_live(evidence)
    check_expansion_shader_compiled(evidence, spec)
    check_no_silent_fallback(evidence)
    check_fixture_live(evidence, spec)
    check_determinism_knobs(evidence, spec)
    check_standards_allowance(evidence, spec)


def check_provenance(evidence, provenance):
    """The knobs in the DUMP equal the knobs RECORDED AS BLESSED (bead oo-3ya).

    check_determinism_knobs compares the dump with spec.json. That catches a spec edited alone. It
    does NOT catch a spec and a golden re-cut TOGETHER at a new seed, because both sides move. The
    blessing record is the third, independent witness: `provenance.json` states the knobs the
    artefact was blessed with, and this raises when the dump disagrees with them.
    """
    knobs = provenance.get("knobs")
    _require(isinstance(knobs, dict) and knobs,
             "provenance.json carries no `knobs` block, so there is nothing to hold the dump's "
             "determinism knobs against. Bead oo-3ya's finding is exactly this: a seed can change "
             "with the gate staying green when the only comparison is spec-vs-golden, since "
             "changing the seed changes BOTH sides.")
    for key in ("seed", "ticks", "system_id", "tick_seconds"):
        _require(key in knobs, "provenance.knobs is missing %r" % key)
    for key in ("seed", "ticks", "system_id"):
        _require(evidence.get(key) == knobs[key],
                 "evidence.%s is %r but provenance.knobs.%s records %r: the dump was not produced "
                 "with the knobs this golden was blessed with"
                 % (key, evidence.get(key), key, knobs[key]))
    want_budget = round(int(knobs["ticks"]) * float(knobs["tick_seconds"]), 3)
    _require(evidence.get("game_seconds_budget") == want_budget,
             "evidence.game_seconds_budget is %r but provenance.knobs implies %r"
             % (evidence.get("game_seconds_budget"), want_budget))


# --- mutants ------------------------------------------------------------------------------------
# Applied to a THROWAWAY COPY, never in place. Each one corrupts exactly ONE property so the RED it
# produces names that property; a mutant that changes two fields proves nothing about either.

def _mutate_shader_dead(state):
    """The silent fixed-function run: GLSL never executed, everything else identical."""
    e = state["evidence"]
    e["shader_uniform_sets_positive"] = False
    e["shader_compile_failures"] = []
    e["shader_load_failures"] = []
    e["glsl_driver_log"] = []
    return state


def _mutate_unsupported(state):
    """The engine reports NO shader support - the hardware-dependent vacuity trap itself."""
    state["evidence"]["shader_support_lines"] = [
        "Shaders will not be used (OpenGL extension GL_ARB_shading_language_100 is not available)."]
    return state


def _mutate_seed(state):
    state["evidence"]["seed"] = int(state["evidence"]["seed"]) + 1
    return state


def _mutate_ticks(state):
    state["evidence"]["ticks"] = int(state["evidence"]["ticks"]) - 1
    return state


def _mutate_quantum(state):
    """Perturb ONE float by ONE quantised unit (3 decimals => 0.001)."""
    ship = state["player"]["ship"]
    ship["position"][0] = round(ship["position"][0] + 0.001, 3)
    return state


def _mutate_driver_log(state):
    """The driver's own diagnostic replaced by plausible-looking text Oolite could have written."""
    state["evidence"]["glsl_driver_log"] = ["shader failed"]
    return state


def _mutate_standards_count(state):
    state["evidence"]["oxp_standards_errors"] = \
        int(state["evidence"]["oxp_standards_errors"]) + 1
    return state


def _mutate_role(state):
    """The cast un-pinned: the bare role a fixed seed does not fix (bead oo-izi)."""
    e = state["evidence"]
    e["demo_ship_role"] = e["demo_ship_role"].strip("[]")
    return state


def _mutate_fallback(state):
    """The reduced-complexity fallback re-enabled upstream: a different observable entirely."""
    state["evidence"]["shader_fallback_markers"] = ["fallbackSuccess", "fullModeFailed"]
    return state


def _mutate_no_link(state):
    """NARROWER THAN shader_dead, and the reason defence 1 is not redundant.

    Leaves every piece of expansion evidence intact - the compile failure, the driver's diagnostic,
    the load failure - and flips ONLY `shader_uniform_sets_positive`. That is a real, reachable
    state: the expansion's shader is rejected (as this fixture's always is) while NO OTHER material
    in the scene managed to link either, i.e. the GLSL path is broken engine-wide. Defence 2 cannot
    see it, because defence 2 only asks about this expansion's file. Defence 1 is the only thing
    that does.
    """
    state["evidence"]["shader_uniform_sets_positive"] = False
    return state


MUTANTS = {
    "shader_dead": _mutate_shader_dead,
    "no_link": _mutate_no_link,
    "unsupported": _mutate_unsupported,
    "seed": _mutate_seed,
    "ticks": _mutate_ticks,
    "quantum": _mutate_quantum,
    "driver_log": _mutate_driver_log,
    "standards_count": _mutate_standards_count,
    "role": _mutate_role,
    "fallback": _mutate_fallback,
}


def _default_spec():
    here = os.path.dirname(os.path.abspath(__file__))
    repo = os.path.abspath(os.path.join(here, "..", ".."))
    for candidate in (os.path.join(here, "scenarios", "009-shaders", "spec.json"),
                      os.path.join(here, "pending", "009-shaders", "spec.json"),
                      os.path.join(repo, "goldens", "windows-x64", "009-shaders", "spec.json")):
        if os.path.isfile(candidate):
            return candidate
    raise EvidenceError("no spec.json for scenario 009-shaders")


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="tests/golden/check_shader_evidence.py", description=__doc__)
    parser.add_argument("dump", help="a state.json carrying an `evidence` block")
    parser.add_argument("out", nargs="?", default=None,
                        help="with --mutate: where to write the mutated COPY")
    parser.add_argument("--spec", default=None)
    parser.add_argument("--provenance", default=None,
                        help="also assert the dump's knobs equal the knobs it was BLESSED with")
    parser.add_argument("--mutate", choices=sorted(MUTANTS),
                        help="write a THROWAWAY mutated copy instead of checking; never edits the "
                             "input")
    args = parser.parse_args(argv)

    with open(args.dump, "r", encoding="utf-8") as handle:
        state = json.load(handle)

    if args.mutate:
        if not args.out:
            print("[!] --mutate needs an output path; a mutant is never written in place",
                  file=sys.stderr)
            return 2
        mutated = MUTANTS[args.mutate](state)
        with open(args.out, "w", encoding="utf-8", newline="\n") as handle:
            json.dump(mutated, handle, sort_keys=True, separators=(",", ":"))
        print("wrote mutant %s -> %s" % (args.mutate, args.out))
        return 0

    with open(args.spec or _default_spec(), "r", encoding="utf-8") as handle:
        spec = json.load(handle)

    evidence = state.get("evidence")
    if not isinstance(evidence, dict):
        print("[!] %s carries no `evidence` block; there is nothing to gate" % args.dump,
              file=sys.stderr)
        return 1
    try:
        check_evidence(evidence, spec)
        if args.provenance:
            with open(args.provenance, "r", encoding="utf-8") as handle:
                check_provenance(evidence, json.load(handle))
    except EvidenceError as exc:
        print("[!] EvidenceError: %s" % exc, file=sys.stderr)
        return 1
    print("009-shaders evidence OK: %s | uniforms linked: %s | compile failures: %s | "
          "driver log: %d line(s) | seed %s ticks %s"
          % (evidence["shader_support_lines"][0],
             evidence["shader_uniform_sets_positive"],
             [f["shader"] for f in evidence["shader_compile_failures"]],
             len(evidence["glsl_driver_log"]), evidence["seed"], evidence["ticks"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
