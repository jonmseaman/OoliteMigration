"""Golden scenario 009-shaders: stage the in-tree `Fallback test.oxp` (shaderFallbackTest), put its
cube ON SCREEN, and prove FROM THE ENGINE'S OWN LOG that the GLSL toolchain is live and that THIS
EXPANSION'S SHADER SOURCE REACHED THE DRIVER'S COMPILER.

WHY THIS SCENARIO IS DIFFERENT FROM 010 AND 007
-----------------------------------------------
007 (bead oo-5k2) asks "did the expansion's JS run"; 010 (bead oo-gxp) asks "was the expansion's
PNG decoded and uploaded". Both are CPU-side questions. Shaders are the most hardware-dependent
thing in this tree: on a box whose renderer has no GLSL the engine says so once at startup and then
SILENTLY RENDERS EVERYTHING WITH FIXED-FUNCTION. The log stays clean, the dump stays quiet, rc=0,
and nothing about shaders was tested. Establishing which world we are in is therefore step one, and
it is recorded IN THE DUMP rather than assumed.

MEASURED ON THIS HOST, VERBATIM FROM A REAL RUN'S OWN Latest.log
----------------------------------------------------------------
The golden harness forces `LIBGL_ALWAYS_SOFTWARE=1` and `GALLIUM_DRIVER=llvmpipe`
(upstream/oolite/tests/component/console.py:_env), which is also the rasteriser bead oo-ae9
calibrated the frame tolerance against (frame_hash.REQUIRED_GL_ENV). So the renderer under test is:

    [rendering.opengl.version]: OpenGL renderer version: 4.6.0 ("4.6 (Compatibility Profile)
        Mesa 26.1.8"). Vendor: "Mesa". Renderer: "llvmpipe (LLVM 22.1.8, 256 bits)".
    [rendering.opengl.shader.support]: Shaders are supported.

SHADERS RUN HERE. That is not inferred from the support line alone - the support line only says the
extensions are present. The engine then LINKS REAL PROGRAMS AND BINDS UNIFORMS TO THEM:

    [shader.uniform.set]: Set up uniform <OOShaderUniform ...>{3: int uDiffuseMap = 0;}
    [shader.uniform.set]: Set up uniform <OOShaderUniform ...>{9: float uHullHeatLevel =
        [<ShipEntity ...> hullHeatLevel];}

Those lines are emitted from OOShaderMaterial -initWithName:... (OOShaderMaterial.m:327 and the
five sibling sites), which is reached only AFTER `OK = (shaderProgram != nil)` at :236 - i.e. only
after glCompileShaderARB AND glLinkProgramARB both returned GL_TRUE for that material
(OOShaderProgram.m:322, :337, :353, validated at :261-267). A fixed-function fallback emits none of
them. This is the anti-vacuity anchor: `shader_uniform_sets` cannot be non-zero on a run that
rendered with fixed function.

WHAT THE FIXTURE IS, AND WHY ITS SHADER IS SUPPOSED TO FAIL
-----------------------------------------------------------
`Fallback test.oxp` is one ship, `ahruman_shader_fallback_test`, whose `cube-face` material names
`ahruman_shader_fallback_test.fragment`. That fragment shader contains a DELIBERATE syntax error;
the fixture's own comment says the shader should go green in simple mode, blue in full mode, and
that the cube goes RED when no shader is in effect. So the OBSERVABLE this scenario pins is the
engine's shader ERROR PATH, driven end to end by the expansion's own file, and the driver's own
diagnostic is the evidence:

    [shader.compile.failure]: ***** ERROR: GLSL fragment shader compilation failed for
        ahruman_shader_fallback_test.fragment:
    >>>>> GLSL log:
    0:4(2): error: illegal use of reserved word `this'
    0:4(2): error: syntax error, unexpected ERROR_TOK
    [shader.load.failed]: ***** ERROR: Could not build shader
        oolite-tangent-space-vertex.vertex/ahruman_shader_fallback_test.fragment.

THAT TEXT CANNOT EXIST UNLESS THE EXPANSION'S SHADER SOURCE WAS HANDED TO THE GL DRIVER. It is not
produced by Oolite: `GetGLSLInfoLog` (OOShaderProgram.m:481) reads it back out of the GL
implementation with glGetInfoLogARB, so the wording is Mesa's GLSL front end reporting on bytes it
was given by glShaderSourceARB (:335). A run in which the OXP was rejected, or in which shaders
were off, produces NO such line - which is exactly what the OXP-ABSENT arm below measures.

SCOPE, STATED PLAINLY. This golden covers: the GLSL path is live on this renderer; real programs
compile, link and bind uniforms; and the expansion's shader file was read, preprocessed and
compiled by the driver. It does NOT cover a SUCCESSFUL OXP shader painting pixels, because the only
shader test-OXP in this tree ships an intentionally invalid shader. A future fixture with a valid
shader would extend this scenario, not replace it.

WHAT THE ENGINE DOES NOT DO ANY MORE, AND WHY THAT IS PINNED
-------------------------------------------------------------
The fixture was written for r3144-era Oolite, which fell back to OO_REDUCED_COMPLEXITY and would
have compiled the `#else` branch (solid green). That fallback is now DISABLED IN THE SOURCE: the
whole block is inside `#if 0` (OOShaderMaterial.m:191-224, commented "no reduced complexity mode
now"), so a failed compile goes straight to `shader.load.failed` at :228 and the material drops to
a non-shader one. `shader_fallback_attempted` records the absence of `shader.load.fullModeFailed` /
`shader.load.fallbackSuccess`: if the reduced-complexity path is ever re-enabled upstream, this
scenario goes RED rather than quietly measuring different behaviour.

THE TWO-ARM FRAME DIFFERENTIAL (the fleet's strongest control, and measured here)
---------------------------------------------------------------------------------
Numbers are in `pending/009-shaders/provenance.json` under `frame_differential` and are reproduced
in LANDING.md. The control answers the question that makes a shader golden worth anything: if
removing the expansion does NOT move the frame, the expansion's content never reached the screen.

DETERMINISM
-----------
The cast is PINNED TO A LITERAL `[shipKey]` ROLE - `mission.runScreen({model: "[ahruman_shader_
fallback_test]"})`. Bead oo-izi proved a bare role is a RANROT draw whose outcome a fixed seed does
not fix; the bracketed form is registered at probability 1.0 by OOShipRegistry.m:1229, so exactly
one ship class can answer. `spinModel:false` because a spinning demo ship (Universe.m:5829) would
have a different orientation in every frame. Traffic is suppressed the way 010 does it and for the
measured reasons recorded there; the demo ship is exempted from clearing by its
STATUS_COCKPIT_DISPLAY status, which is what `makeDemoShipWithRole:` sets (Universe.m:5835).

THE MISSING manifest.plist (bead oo-kcrw NOMANIF, mechanism proved by bead oo-dto)
-----------------------------------------------------------------------------------
Measured for THIS expansion, verbatim:

    [oxp-standards.error]: OXP <staged>/Fallback test.oxp has no manifest.plist
    [oxp-standards.error]: OXP <staged>/Fallback test.oxp has no manifest.plist
    [searchPaths.dumpAll]: Resource paths:
        <staged>/Fallback test.oxp

Exactly two, and the path IS on searchPaths - the `.oxp` branch of ResourceManager.m:636-664,
which emits OOStandardsError at :646 and synthesises a basic manifest at :654-663 rather than
returning as an `.oxz` would at :640. CHOICE: allow-list by EXACT message and EXACT count. No
manifest is staged, because staging one would fabricate content the fixture does not have and
would measure a fixture that does not exist in the tree.
"""

import argparse
import json
import os
import re
import shutil
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
DUMP_DIR = os.path.join(HERE, "dump")

sys.path.insert(0, HERE)
sys.path.insert(0, DUMP_DIR)
sys.path.insert(0, os.path.join(REPO_ROOT, "upstream", "oolite", "tests", "component"))

import frame_hash  # noqa: E402
import golden_run  # noqa: E402

# NO DESKTOP LOCK, deliberately: this is a golden-harness scenario driver, exempt from tools/gui-lock
# on golden_run.py's terms (see its module docstring and tools/check-desktop-lock.sh). It launches
# through golden_run's per-run isolation - a reserved port, a staged private app dir, a private
# artifact dir - which exists so that golden runs can share one machine AT ONCE (stability sweeps,
# tier-b/tier-c golden stages, and several fleet worktrees' acceptance lines side by side). The
# desktop mutex is exclusive, so taking it here would serialise all of them into a queue of one.
# The run never needs the FOREGROUND: no synthetic input, no window click, readiness over the
# console socket, and every frame is rendered game-side from the game's own framebuffer. If this
# scenario ever starts to need the foreground it stops being exempt and must take the lock.
from state_dump import dump_state, ensure_launchable, start_with_retry  # noqa: E402

SCENARIO = "009-shaders"

SPEC_CANDIDATES = (
    os.path.join(HERE, "scenarios", SCENARIO, "spec.json"),
    os.path.join(HERE, "pending", SCENARIO, "spec.json"),
)
GOLDEN_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "state.json"),
    os.path.join(HERE, "pending", SCENARIO, "state.json"),
)
FRAME_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "frame.grid"),
    os.path.join(HERE, "pending", SCENARIO, "frame.grid"),
)

TICK_WALL_BUDGET_SECONDS = 300
FRAME_SETTLE_SECONDS = 1.5
SETTLE_TIMEOUT_SECONDS = 120
CLEAR_ROUNDS = 20

OXP_STANDARDS_RE = re.compile(r"\[oxp-standards\.error\]:\s*(.*)")
# OOShaderProgram.m:264-265 -- the message class is CONSTRUCTED ("shader.%@.failure"), so it does
# not appear as a literal in the source; logcontrol.plist:344-347 documents that explicitly.
SHADER_FAILURE_RE = re.compile(
    r"\[shader\.(compile|link)\.failure\]:.*?failed for ([^\s:]+(?:\.[a-z]+)?):")
SHADER_LOAD_FAILED_RE = re.compile(r"\[shader\.load\.failed\]:.*?Could not build shader (\S+)\.")
SHADER_UNIFORM_SET_RE = re.compile(r"\[shader\.uniform\.set\]:")
# OOOpenGLExtensionManager.m:289 / :280 / :572 / :592 - all four outcomes on one channel.
SHADER_SUPPORT_RE = re.compile(r"\[rendering\.opengl\.shader\.support\]:\s*(.*)")
GL_VERSION_RE = re.compile(r"\[rendering\.opengl\.version\]:\s*(.*)")
# A normal engine log line is "HH:MM:SS.mmm [channel]: ...". The driver's GLSL diagnostic has NO
# such prefix, because it is text the GL implementation produced and Oolite merely interpolated
# (OOShaderProgram.m:265). That difference is what bounds the capture below - MEASURED: without
# it the capture ran on into the next two engine lines, which carry a WALL-CLOCK TIMESTAMP and an
# OOShaderUniform POINTER ADDRESS and so differ on every run, making a byte-identical golden
# impossible.
ENGINE_LOG_LINE_RE = re.compile(r"^\d{2}:\d{2}:\d{2}[.\d]*\s*\[|^\[")


FALLBACK_RE = re.compile(r"\[shader\.load\.(fullModeFailed|fallbackSuccess)\]")


class ScenarioError(RuntimeError):
    pass


def _first_existing(candidates, what):
    for path in candidates:
        if os.path.isfile(path):
            return path
    raise ScenarioError("no %s found; looked in: %s" % (what, ", ".join(candidates)))


def spec_path():
    return _first_existing(SPEC_CANDIDATES, "spec.json for scenario %s" % SCENARIO)


def golden_path():
    return _first_existing(GOLDEN_CANDIDATES, "stored golden for scenario %s" % SCENARIO)


def frame_path():
    return _first_existing(FRAME_CANDIDATES, "stored reference frame grid for %s" % SCENARIO)


def load_spec(path=None):
    with open(path or spec_path(), "r", encoding="utf-8") as handle:
        return json.load(handle)


def oxp_source(spec):
    src = os.path.join(REPO_ROOT, *spec["oxp_source"].split("/"))
    if not os.path.isdir(src):
        raise ScenarioError(
            "the test-OXP this scenario is about is not in the tree at %s; a run staging nothing "
            "would still load the game and would dump a world with no expansion in it" % src)
    return src


def stage_oxp(spec, addons_dir, twice=False):
    """Copy the expansion into a private addons root and return its staged path.

    THE DIRECTORY IS CALLED `oxp-stage`, NOT `addons`, AND THAT IS LOAD-BEARING: the game also
    searches `<app dir>/../AddOns`, and the staged app lives at `<artifact>/app`, so
    `<artifact>/addons` IS `<artifact>/../AddOns` on a case-insensitive filesystem - bead oo-3ya
    measured FOUR missing-manifest errors instead of two that way. `twice` reproduces that
    double-root state on purpose so the exact-count predicate can be PROVEN to fire.
    """
    src = oxp_source(spec)
    os.makedirs(addons_dir, exist_ok=True)
    target = os.path.join(addons_dir, os.path.basename(src))
    shutil.copytree(src, target)
    if not os.path.isdir(target):
        raise ScenarioError("staging %s -> %s produced nothing" % (src, target))
    if twice:
        shutil.copytree(src, os.path.join(addons_dir, "Fallback test copy.oxp"))
    return golden_run._slashes(target)


def assert_system(console, spec):
    got = console.evaluate_int("system.ID")
    if got != int(spec["system_id"]):
        raise ScenarioError(
            "scenario %s is pinned to system ID %d (%s) but the loaded save is in system ID %d"
            % (SCENARIO, int(spec["system_id"]), spec.get("system_name", "?"), got))
    return got


def detail_level(console, spec):
    """The graphics detail level, read from the RUNNING game, and required to be shader-capable.

    `useShaders` IS `detailLevel >= DETAIL_LEVEL_SHADERS` (Universe.m:10081-10084) and
    OOMaterialConvenienceCreators.m:278 gates every shader material on it. Below that threshold the
    engine builds OOSingleTextureMaterial/OOBasicMaterial instead and NOTHING in the log says a
    shader was skipped - the silent fixed-function fallback this scenario exists to rule out. So
    the level is read back and pinned rather than hoped for.
    """
    got = console.evaluate("String(oolite.gameSettings.detailLevel)").strip()
    if got not in spec["shader_capable_detail_levels"]:
        raise ScenarioError(
            "the running game reports detailLevel %r, which is not one of the shader-capable "
            "levels %r. Universe -useShaders is `detailLevel >= DETAIL_LEVEL_SHADERS` "
            "(Universe.m:10083) and every shader material is gated on it "
            "(OOMaterialConvenienceCreators.m:278), so below that threshold the engine renders "
            "with fixed function and says nothing about it. A shader golden taken there would be "
            "vacuous." % (got, spec["shader_capable_detail_levels"]))
    return got


def enable_shader_logging(console, spec):
    """Turn on the shader channels this scenario's evidence is read from, and PROVE they are on.

    `shader.uniform` is `$shaderDebugOn = no` by default (logcontrol.plist:37, :336), so the
    uniform lines - the positive proof that programs LINKED - are absent unless asked for. A run
    that merely asked and did not check would produce `shader_uniform_sets == 0`, which is
    indistinguishable from "the engine rendered with fixed function". The failure channels are on
    by default ($error) and are re-asserted for the same reason.
    """
    channels = list(spec["shader_log_channels"])
    for channel in channels:
        console.perform("debugConsole.setDisplayMessagesInClass(%s, true);" % json.dumps(channel))
    off = []
    for channel in channels:
        state = console.evaluate(
            "String(debugConsole.displayMessagesInClass(%s))" % json.dumps(channel)).strip()
        if state.lower() != "true":
            off.append("%s=%s" % (channel, state))
    if off:
        raise ScenarioError(
            "these log channels did not switch on: %s. Every piece of shader evidence in this "
            "scenario is read off those channels; with them off an empty evidence list would mean "
            "'not logged' rather than 'no shader ran', and the two must not be confusable."
            % ", ".join(off))
    return channels


def shipdata_probe(console, spec):
    """Read the fixture's ship entry back out of the RUNNING engine's merged registry.

    `Ship.shipDataForKey` (OOJSShip.m:578) reads the MERGED registry, so this resolving proves the
    expansion's Config/shipdata.plist was parsed and merged - not merely present on disk. The two
    shader filenames it returns are the names the engine will later ask the GL driver to compile,
    so they tie the registry evidence and the log evidence to the same material.
    """
    key = spec["shipdata_key"]
    raw = console.evaluate(
        "(function(){ var d = Ship.shipDataForKey(%s);"
        " if (!d) return 'ABSENT';"
        " var m = d.materials && d.materials[%s];"
        " return JSON.stringify([String(d.name), String(m && m.fragment_shader),"
        "   String(m && m.vertex_shader)]); })()"
        % (json.dumps(key), json.dumps(spec["material_key"]))).strip()
    if raw == "ABSENT":
        raise ScenarioError(
            "Ship.shipDataForKey(%r) is absent from the merged ship registry: the expansion's "
            "shipdata.plist was not merged, so nothing names a shader for the engine to compile"
            % key)
    try:
        name, fragment, vertex = json.loads(raw)
    except ValueError as exc:
        raise ScenarioError("the shipdata probe came back unparseable (%s): %r" % (exc, raw[:200]))
    return {"name": name, "fragment_shader": fragment, "vertex_shader": vertex}


def suppress_populators(console):
    """Switch the system populator off at the source (as 001/010/012)."""
    keys = console.evaluate(
        "(function(){ var s = system.populatorSettings, out = [];"
        " for (var k in s) out.push(k);"
        " for (var i = 0; i < out.length; i++) system.setPopulator(out[i], null);"
        " return out.join(','); })()").strip()
    remaining = console.evaluate(
        "(function(){ var n = 0; for (var k in system.populatorSettings) n++;"
        " return String(n); })()").strip()
    if remaining not in ("0", ""):
        raise ScenarioError(
            "%s populator setting(s) survived suppression; the system will keep adding traffic "
            "during the run, consuming a per-run-variable number of RANROT draws" % remaining)
    return [k for k in keys.split(",") if k]


def suppress_station_traffic(console):
    """Switch off EVERY station's own NPC traffic and prove none is left on.

    StationEntity -update (StationEntity.m:960-995) runs its own launch schedule gated on
    `hasNPCTraffic` and on nothing the system populator owns; bead oo-gxp measured five different
    dumps in ten runs with only the system populator off.
    """
    raw = console.evaluate(
        "(function(){ var e = system.stations, off = 0, on = [];"
        " for (var i = 0; i < e.length; i++) {"
        "   e[i].hasNPCTraffic = false; off++;"
        "   if (e[i].hasNPCTraffic) on.push(e[i].name); }"
        " return JSON.stringify([off, on]); })()").strip()
    try:
        count, still_on = json.loads(raw)
    except ValueError as exc:
        raise ScenarioError("station traffic suppression came back unparseable (%s): %r"
                            % (exc, raw[:200]))
    if still_on:
        raise ScenarioError(
            "these station(s) still report hasNPCTraffic after it was written false: %r"
            % (still_on,))
    if not count:
        raise ScenarioError(
            "no station was found to suppress; the scenario is docked at Lave's main station by "
            "construction, so zero stations means the save did not load the world this scenario "
            "is about")
    return count


def suppress_repopulator(console, spec):
    """Neuter `oolite-populator`'s repopulate handler and prove the replacement took.

    Neither the populator settings nor `hasNPCTraffic` touch `systemWillRepopulate`, and its
    station picker `_tradeStation` ENDS WITH an unconditional `return system.mainStation`, so
    switching the station's traffic off does not stop it (measured by bead oo-gxp).
    """
    quieted = []
    for name in spec["repopulator_handlers"]:
        before = console.evaluate(
            "String(typeof worldScripts['oolite-populator'][%s])" % json.dumps(name)).strip()
        if before == "undefined":
            raise ScenarioError(
                "worldScripts['oolite-populator'].%s does not exist. If it has been renamed "
                "upstream the suppression is silently doing nothing and this scenario is no "
                "longer deterministic; re-derive the name rather than dropping the check." % name)
        console.perform(
            "worldScripts['oolite-populator'][%s] = function(){};" % json.dumps(name))
        after = console.evaluate(
            "String(worldScripts['oolite-populator'][%s].toString().replace(/\\s+/g,''))"
            % json.dumps(name)).strip()
        if "function(){}" not in after:
            raise ScenarioError(
                "worldScripts['oolite-populator'].%s did not become a no-op (it reads %r)"
                % (name, after[:120]))
        quieted.append(name)
    return quieted


# The demo ship is STATUS_COCKPIT_DISPLAY (Universe.m:5835) and is the whole point of the frame, so
# it is exempt from clearing AND from the motion check. Every other non-player, non-station ship is
# traffic and must go.
_NOT_SCENERY = ("!s[i].isPlayer && !s[i].isStation && "
                "String(s[i].status) !== 'STATUS_COCKPIT_DISPLAY'")


def clear_system(console):
    """Remove every non-player, non-station, non-demo ship; report removed AND remaining."""
    removed = console.evaluate_int(
        "(function(){ var s = system.allShips, n = 0;"
        " for (var i = 0; i < s.length; i++) { if (%s) { s[i].remove(); n++; } }"
        " return n; })()" % _NOT_SCENERY)
    remaining = console.evaluate_int(
        "(function(){ var s = system.allShips, n = 0;"
        " for (var i = 0; i < s.length; i++) { if (%s) n++; }"
        " return n; })()" % _NOT_SCENERY)
    return removed, remaining


def moving_entities(console):
    """Every ship reporting motion, as 'name=magnitude' strings.

    `magnitude` IS A FUNCTION: bead oo-jor measured a version that compared the function OBJECT
    with a number, so the guard passed on every run including the ones that should have refused.
    """
    raw = console.evaluate(
        "(function(){ var s = system.allShips, bad = [];"
        " for (var i = 0; i < s.length; i++) {"
        "   if (%s && s[i].velocity.magnitude() > 0.0005)"
        "     bad.push((s[i].shipUniqueName || s[i].name) + '=' +"
        "              s[i].velocity.magnitude().toFixed(4)); }"
        " return bad.join(', '); })()" % _NOT_SCENERY).strip()
    return [part for part in raw.split(", ") if part]


def quiesce(console, rounds=CLEAR_ROUNDS):
    """Clear AND settle as ONE fixed point; refuse if the world never reaches it."""
    history = []
    for _ in range(rounds):
        removed, remaining = clear_system(console)
        moving = moving_entities(console)
        history.append([removed, remaining, len(moving)])
        if removed == 0 and remaining == 0 and not moving:
            return history
        time.sleep(0.3)
    raise ScenarioError(
        "the world never went quiet: %d rounds went %r ([removed, remaining, moving] per round). "
        "The three known sources (system.populatorSettings, StationEntity's own schedule, "
        "oolite-populator's systemWillRepopulate) are all switched off before this runs; a fourth "
        "is a FINDING. Do not widen the round count to paper over it." % (rounds, history))


def run_ticks(console, ticks, tick_seconds):
    """Advance `ticks` AI ticks of GAME time and return the elapsed game seconds."""
    budget = ticks * tick_seconds
    start = float(console.evaluate("clock.absoluteSeconds"))
    deadline = time.time() + TICK_WALL_BUDGET_SECONDS
    while time.time() < deadline:
        elapsed = float(console.evaluate("clock.absoluteSeconds")) - start
        if elapsed >= budget:
            return elapsed
        time.sleep(0.1)
    raise ScenarioError("game time did not advance %ss within %ss of wall time"
                        % (budget, TICK_WALL_BUDGET_SECONDS))


def settle(console, seconds=FRAME_SETTLE_SECONDS, timeout=SETTLE_TIMEOUT_SECONDS):
    """Advance on the GAME's clock, never ours: a fixed sleep snapshots whatever frame was up."""
    start = float(console.evaluate("clock.absoluteSeconds"))
    deadline = time.time() + timeout
    while time.time() < deadline:
        if float(console.evaluate("clock.absoluteSeconds")) - start >= seconds:
            return
        time.sleep(0.25)
    raise ScenarioError("game clock did not advance %ss within %ss" % (seconds, timeout))


def assert_at_rest(console):
    """The world is still, without pauseGame() - which REFUSES on a mission screen.

    GlobalPauseGame (OOJSGlobal.m:831-856) returns NO without pausing while guiScreen is
    GUI_SCREEN_MISSION, and this scenario's whole point is a mission screen. An unchecked pause
    would be worse than none, so the guard is the direct one.
    """
    moving = moving_entities(console)
    if moving:
        raise ScenarioError(
            "%d entity/entities still report motion: %s. ShipEntity -velocity is [super velocity] "
            "+ [self thrustVector] (ShipEntity.m:12830-12833), so a ship under thrust reads a "
            "non-zero velocity no JS write can clear and whose value depends on the frame count."
            % (len(moving), ", ".join(moving)))
    if console.evaluate("player.ship.docked").strip().lower() != "true":
        raise ScenarioError(
            "the player is not docked. makeDemoShipWithRole: returns nil unless the player has a "
            "dockedStation (Universe.m:5808), so undocked there is no cube on screen at all.")
    return True


def show_cube(console, spec, bare_role=False, no_model=False):
    """Open the mission screen carrying the fixture's cube, and prove the cube is THE FIXTURE'S.

    THE ROLE IS THE LITERAL `[shipKey]` FORM, and that is the determinism pin. `runScreen`'s
    `model` goes to `makeDemoShipWithRole:` -> `newShipWithRole:` (Universe.m:5815), which for a
    bare role is a RANROT draw over every ship registered for it (bead oo-izi: Universe.m:4008 ->
    :3948 -> OOShipRegistry.m:276-279), so a fixed seed does NOT fix the cast. `[key]` is
    registered at probability 1.0 by OOShipRegistry.m:1229 and admits exactly one ship.

    `bare_role` and `no_model` are MUTANTS: the first asks for the unbracketed role, the second
    opens the identical screen with no model at all.
    """
    config = {"title": "", "message": "\n\n\n", "spinModel": False}
    requested = None
    if not no_model:
        requested = spec["bare_role"] if bare_role else spec["demo_ship_role"]
        config["model"] = requested
    opened = console.evaluate(
        "(function(){ try { return String(mission.runScreen(%s)); }"
        " catch (e) { return 'ERR ' + e; } })()" % json.dumps(config)).strip()
    if opened.lower() != "true":
        raise ScenarioError(
            "mission.runScreen did not open (returned %r); without it there is no frame carrying "
            "the expansion's cube and the graphical evidence is absent" % opened)
    screen = console.evaluate("guiScreen").strip()
    if screen != "GUI_SCREEN_MISSION":
        raise ScenarioError(
            "guiScreen is %r, not GUI_SCREEN_MISSION, after runScreen returned true" % screen)
    model = console.evaluate(
        "(function(){ var m = mission.displayModel;"
        " return m ? JSON.stringify([String(m.name), String(m.dataKey)]) : 'NONE'; })()").strip()
    if model == "NONE":
        return screen, requested, None, None
    try:
        name, data_key = json.loads(model)
    except ValueError as exc:
        raise ScenarioError("mission.displayModel came back unparseable (%s): %r"
                            % (exc, model[:200]))
    return screen, requested, name, data_key


def capture_frame(console, artifact_dir, attempts=20):
    """Snapshot the current frame and return (png path, 64x64 luminance grid).

    The file NAME appears before the bytes do: on Windows the game still holds the handle open, so
    reading immediately fails with PermissionError or could hash a truncated image. Both are
    retried; a frame that never becomes readable is a REFUSAL, not a hash of half a file.
    """
    before = set(f for f in os.listdir(artifact_dir) if f.endswith(".png"))
    console.perform("takeSnapShot();")
    png = golden_run._await_png(artifact_dir, before)
    last = None
    for _ in range(attempts):
        try:
            return png, frame_hash.frame_grid(png)
        except (PermissionError, OSError, ValueError) as exc:
            last = exc
            time.sleep(0.25)
    raise ScenarioError(
        "the snapshot at %s never became readable (%s: %s)" % (png, type(last).__name__, last))


def normalise_oxp_error(message, oxp_basename):
    """Replace the volatile staged path with the OXP's basename; compare the rest VERBATIM.

    The staged root carries a timestamp, a port and a pid, so the raw message differs on every run
    by construction. `\\S*` is anchored to the basename and cannot cross a space, which matters
    HERE more than it did for scenario 010: this fixture's basename CONTAINS a space ("Fallback
    test.oxp"). A looser pattern that spans spaces swallows the leading "OXP " as well and
    silently turns the allow-list into a different (weaker) string - measured on the first run of
    this scenario, which refused with 'Fallback test.oxp has no manifest.plist' against an
    allow-list of 'OXP Fallback test.oxp has no manifest.plist'. The refusal was correct.
    """
    return re.sub(r"\S*%s" % re.escape(oxp_basename), oxp_basename, message).strip()


def read_log_evidence(artifact_dir, oxp_basename):
    """Collect every piece of shader and standards evidence from THIS run's own Latest.log."""
    log = os.path.join(artifact_dir, "Latest.log")
    if not os.path.isfile(log):
        raise ScenarioError(
            "no Latest.log at %s: the run wrote no log, so neither the missing-manifest allowance "
            "nor any shader evidence can be checked at all" % log)
    with open(log, "r", encoding="utf-8", errors="replace") as handle:
        text = handle.read()
    lines = text.splitlines()

    standards = [normalise_oxp_error(m.group(1), oxp_basename)
                 for m in OXP_STANDARDS_RE.finditer(text)]

    support = [m.group(1).strip() for m in SHADER_SUPPORT_RE.finditer(text)]
    gl_version = [m.group(1).strip() for m in GL_VERSION_RE.finditer(text)]

    compile_failures, glsl_log = [], []
    for index, line in enumerate(lines):
        match = SHADER_FAILURE_RE.search(line)
        if not match:
            continue
        compile_failures.append({"stage": match.group(1), "shader": match.group(2)})
        # The driver's own diagnostic follows the ">>>>> GLSL log:" marker
        # (OOShaderProgram.m:265). It is read back out of GL by GetGLSLInfoLog (:481), so its
        # wording is the GL implementation's, not Oolite's.
        for follow in lines[index + 1:index + 8]:
            stripped = follow.strip()
            if not stripped or stripped.startswith(">>>>>"):
                continue
            if ENGINE_LOG_LINE_RE.search(stripped):
                break
            glsl_log.append(stripped)
    load_failures = [m.group(1) for m in SHADER_LOAD_FAILED_RE.finditer(text)]
    uniform_sets = len(SHADER_UNIFORM_SET_RE.findall(text))
    fallback = [m.group(1) for m in FALLBACK_RE.finditer(text)]

    return {
        "standards": standards,
        "shader_support_lines": support,
        "gl_version_lines": gl_version,
        "compile_failures": compile_failures,
        "glsl_driver_log": glsl_log,
        "load_failures": load_failures,
        "uniform_sets": uniform_sets,
        "fallback_markers": fallback,
        "log_bytes": len(text),
    }


def assert_ran(evidence, spec):
    """The anti-vacuity gate, applied BEFORE anything is written.

    Every clause names a field the dump CARRIES, so the same property is re-checked by every future
    diff against the stored golden rather than only at capture time. The offline half lives in
    check_shader_evidence.py so a stored dump can be re-gated with no game.
    """
    from check_shader_evidence import check_evidence  # noqa: E402  (same directory)

    check_evidence(evidence, spec)


def canonical(obj):
    """The one serialisation used for the golden, for a fresh run, and for the hash."""
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def run(app_dir, out_path, spec, run_root, keep=False, stage=True, empty_stage=False,
        stage_double=False, no_model=False, bare_role=False, seed_override=None,
        ticks_override=None, frame_out=None):
    from console import DebugConsole  # noqa: E402  (path valid only after sys.path setup)

    seed = int(spec["seed"] if seed_override is None else seed_override)
    ticks = int(spec["ticks"] if ticks_override is None else ticks_override)
    oxp_basename = os.path.basename(spec["oxp_source"].rstrip("/"))

    os.makedirs(run_root, exist_ok=True)
    port = golden_run.reserve_port(run_root)
    stamp = "%s-p%d-%d" % (time.strftime("%H%M%S", time.gmtime()), port, os.getpid())
    artifact_dir = golden_run._slashes(os.path.join(run_root, "%s-%s" % (SCENARIO, stamp)))
    staged = golden_run._slashes(os.path.join(artifact_dir, "app"))
    config_dir = golden_run._slashes(os.path.join(artifact_dir, "console-config"))
    addons_dir = golden_run._slashes(os.path.join(artifact_dir, "oxp-stage"))

    os.makedirs(artifact_dir, exist_ok=True)
    golden_run.stage_app(app_dir, staged)
    golden_run._write_console_config(config_dir, "127.0.0.1", port)

    if empty_stage:
        os.makedirs(addons_dir, exist_ok=True)
        staged_oxp = None
    else:
        staged_oxp = stage_oxp(spec, addons_dir, twice=stage_double) if stage else None

    roots = [config_dir] + ([addons_dir] if stage or empty_stage else [])
    previous = os.environ.get("OO_ADDITIONALADDONSDIRS")
    os.environ["OO_ADDITIONALADDONSDIRS"] = ",".join(roots + ([previous] if previous else []))
    started = time.time()
    try:
        console = start_with_retry(lambda: DebugConsole(
            staged, port, seed=seed, output_dir=artifact_dir, host="127.0.0.1",
            load_save=spec["load_save"]))
        with console:
            assert_system(console, spec)
            detail = detail_level(console, spec)
            channels = enable_shader_logging(console, spec)

            # SUPPRESSION FIRST, BEFORE ANY SLOW PROBE: bead oo-gxp measured eight of ten runs
            # refusing with a launched ship still under thrust when the probe came first.
            suppressed = suppress_populators(console)
            stations_quieted = suppress_station_traffic(console)
            repopulator_handlers = suppress_repopulator(console, spec)
            quiesce(console)

            shipdata = {}
            if stage:
                shipdata = shipdata_probe(console, spec)

            elapsed = run_ticks(console, ticks, float(spec["tick_seconds"]))

            # SCREEN FIRST, THEN SETTLE, THEN QUIESCE, THEN MEASURE. Clearing to a fixed point and
            # THEN switching screens leaves seconds in which a ship can arrive; the demo ship
            # itself survives quiesce because it is STATUS_COCKPIT_DISPLAY (see _NOT_SCENERY).
            gui_screen, requested_role, model_name, model_key = show_cube(
                console, spec, bare_role=bare_role, no_model=no_model)
            settle(console)
            clear_rounds = quiesce(console)
            at_rest = assert_at_rest(console)
            png, grid = capture_frame(console, artifact_dir)
            state = json.loads(dump_state(console))

        # AFTER the game has exited, so the log is complete and flushed.
        log = read_log_evidence(artifact_dir, oxp_basename)

        evidence = {
            "scenario": SCENARIO,
            "oxp_staged": bool(stage or empty_stage),
            "oxp_basename": oxp_basename,
            "detail_level": detail,
            "shader_support_lines": log["shader_support_lines"],
            "gl_renderer_lines": log["gl_version_lines"],
            "shader_uniform_sets_positive": log["uniform_sets"] > 0,
            # The COUNT is deliberately not pinned: it is how many materials this particular frame
            # happened to build, which depends on what the station's model needed. That it is
            # NON-ZERO is the assertion, and that cannot be true of a fixed-function run.
            "shader_compile_failures": sorted(
                log["compile_failures"], key=lambda f: (f["stage"], f["shader"])),
            "shader_load_failures": sorted(set(log["load_failures"])),
            "glsl_driver_log": log["glsl_driver_log"],
            "shader_fallback_markers": sorted(set(log["fallback_markers"])),
            "shipdata": shipdata,
            # The role ACTUALLY ASKED FOR, read back from the call, NOT copied out of
            # the spec. MEASURED: the first version recorded spec["demo_ship_role"]
            # here, so the --bare-role mutant - which asks the engine for the
            # unbracketed, RANROT-drawn role - produced a dump claiming the bracketed
            # one and passed the gate. A knob recorded from the spec cannot witness
            # the spec being disobeyed; it is decoration. This is the value under test.
            "demo_ship_role": requested_role,
            "demo_model_name": model_name,
            "demo_model_key": model_key,
            "shader_log_channels": sorted(channels),
            "oxp_standards_errors": len(log["standards"]),
            "oxp_standards_error_signatures": sorted(set(log["standards"])),
            "gui_screen": gui_screen,
            "world_at_rest": bool(at_rest),
            "tick_budget_met": bool(elapsed >= ticks * float(spec["tick_seconds"])),
            "game_seconds_budget": round(ticks * float(spec["tick_seconds"]), 3),
            "ticks": ticks,
            "seed": seed,
            "system_id": int(spec["system_id"]),
            "populators_suppressed": len(suppressed),
            "stations_quieted": stations_quieted,
            "repopulator_handlers_quieted": sorted(repopulator_handlers),
            "world_reached_fixed_point": bool(clear_rounds) and clear_rounds[-1] == [0, 0, 0],
        }
        assert_ran(evidence, spec)
        state["evidence"] = evidence
        text = canonical(state)
        if out_path:
            parent = os.path.dirname(os.path.abspath(out_path))
            if parent:
                os.makedirs(parent, exist_ok=True)
            with open(out_path, "w", encoding="utf-8", newline="\n") as handle:
                handle.write(text)
        if frame_out:
            parent = os.path.dirname(os.path.abspath(frame_out))
            if parent:
                os.makedirs(parent, exist_ok=True)
            with open(frame_out, "wb") as handle:
                handle.write(bytes(grid))
        return {"ok": True, "out": out_path, "frame_out": frame_out, "port": port,
                "staged_oxp": staged_oxp, "png": golden_run._slashes(png),
                "frame_hash": frame_hash.hex_digest(grid),
                "wall_seconds": round(time.time() - started, 1), "bytes": len(text),
                "log_bytes": log["log_bytes"], "game_seconds_elapsed": round(elapsed, 3),
                "evidence": evidence}
    finally:
        if previous is None:
            os.environ.pop("OO_ADDITIONALADDONSDIRS", None)
        else:
            os.environ["OO_ADDITIONALADDONSDIRS"] = previous
        if not keep:
            golden_run.unstage_app(staged)
            shutil.rmtree(addons_dir, ignore_errors=True)
        golden_run.release_all()


def default_app_dir():
    for candidate in (os.environ.get("OO_APP_DIR"),
                      os.path.join(REPO_ROOT, "upstream", "oolite", "build", "meson_test",
                                   "oolite.app"),
                      "C:/Users/jon/OoliteMigration/upstream/oolite/build/meson_test/oolite.app"):
        if candidate and os.path.isdir(candidate):
            return golden_run._slashes(os.path.abspath(candidate))
    return None


def compare_frame(grid_path, reference_path, tol=None):
    """Compare a captured grid with a reference under the MEASURED tolerance (oo-ae9)."""
    tol = frame_hash.derive_tolerance() if tol is None else tol
    with open(grid_path, "rb") as handle:
        got = handle.read()
    with open(reference_path, "rb") as handle:
        want = handle.read()
    if len(got) != frame_hash.GRID_CELLS or len(want) != frame_hash.GRID_CELLS:
        raise ScenarioError(
            "a frame grid is not %d bytes (%s=%d, %s=%d); the comparison would be meaningless"
            % (frame_hash.GRID_CELLS, grid_path, len(got), reference_path, len(want)))
    d = frame_hash.distance(got, want)
    return {"distance": d, "tolerance": tol, "within": d <= tol,
            "ratio": d / tol if tol else float("inf"),
            "hash_got": frame_hash.hex_digest(got), "hash_want": frame_hash.hex_digest(want)}


def main(argv=None):
    parser = argparse.ArgumentParser(prog="tests/golden/shader_fallback.py", description=__doc__)
    parser.add_argument("--app-dir", default=None)
    parser.add_argument("--out", default=None, help="write the canonical dump here")
    parser.add_argument("--frame-out", default=None, help="write the 64x64 luminance grid here")
    parser.add_argument("--run-root", default=None, help="scratch root for staged apps/artifacts")
    parser.add_argument("--keep", action="store_true")
    parser.add_argument("--seed", type=int, default=None, help="override the spec's seed")
    parser.add_argument("--ticks", type=int, default=None, help="override the spec's tick count")
    parser.add_argument("--empty-stage", action="store_true",
                        help="MUTANT: create the staging directory but REMOVE the expansion from "
                             "it, so the run reaches and trips the shader-evidence assertions "
                             "rather than the staging one")
    parser.add_argument("--stage-double", action="store_true",
                        help="MUTANT: stage the expansion at TWO paths, reproducing the "
                             "case-insensitive double-root state; must trip the EXACT "
                             "missing-manifest count")
    parser.add_argument("--no-model", action="store_true",
                        help="MUTANT: open the identical mission screen with NO model")
    parser.add_argument("--bare-role", action="store_true",
                        help="MUTANT: ask for the UNBRACKETED role, which is a RANROT draw "
                             "(bead oo-izi) rather than the pinned single ship")
    parser.add_argument("--no-oxp", action="store_true",
                        help="MUTANT / CONTROL ARM: stage no expansion at all. Used to measure "
                             "the OXP-absent frame for the two-arm differential.")
    parser.add_argument("--compare-frame", nargs=2, metavar=("GRID", "REFERENCE"),
                        help="offline: compare two stored grids and exit 0/1")
    parser.add_argument("--allow-red", action="store_true",
                        help="for the CONTROL ARM only: write the dump and frame even when the "
                             "evidence gate refuses, so the absent arm's frame can be measured")
    args = parser.parse_args(argv)

    if args.compare_frame:
        try:
            result = compare_frame(*args.compare_frame)
        except Exception as exc:  # noqa: BLE001
            print("[!] %s: %s" % (type(exc).__name__, exc), file=sys.stderr)
            return 2
        json.dump(result, sys.stdout, indent=2, sort_keys=True)
        sys.stdout.write("\n")
        return 0 if result["within"] else 1

    spec = load_spec()
    app_dir = args.app_dir or default_app_dir()
    if not app_dir or not os.path.isdir(app_dir):
        print("[!] no Oolite build; pass --app-dir or set OO_APP_DIR", file=sys.stderr)
        return 1
    ensure_launchable(app_dir)

    run_root = args.run_root or os.path.join(
        os.environ.get("LOCALAPPDATA", os.path.expanduser("~")), "Temp", "oo_rad_runs")
    run_root = golden_run._slashes(os.path.abspath(run_root))

    if args.allow_red:
        # THE CONTROL ARM IS A DELIBERATE RED. Its gate failure is the finding, not an accident,
        # and its FRAME is the measurement - so the run is repeated with the gate bypassed only
        # here, and never on the blessing path.
        global assert_ran  # noqa: PLW0603
        original = assert_ran

        def assert_ran(evidence, spec_):  # noqa: F811
            try:
                original(evidence, spec_)
            except Exception as exc:  # noqa: BLE001
                print("[control-arm] evidence gate refused as expected: %s" % exc,
                      file=sys.stderr)

    try:
        result = run(app_dir, args.out, spec, run_root, keep=args.keep,
                     stage=not (args.no_oxp or args.empty_stage),
                     empty_stage=args.empty_stage, stage_double=args.stage_double,
                     no_model=args.no_model, bare_role=args.bare_role,
                     seed_override=args.seed, ticks_override=args.ticks,
                     frame_out=args.frame_out)
    except Exception as exc:  # noqa: BLE001 - the CLI reports; the library raises
        print("[!] %s: %s" % (type(exc).__name__, exc), file=sys.stderr)
        return 1
    json.dump(result, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
