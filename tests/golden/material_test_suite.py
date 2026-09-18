"""Golden scenario 008-material-test-suite: load the in-tree Material Test Suite test-OXP, prove
its MATERIAL definitions reached the RENDERER, run a FIXED number of game ticks, and emit a
canonical dump plus a reference frame grid.

EXEMPLARS: scenario 010 (`tests/golden/png_test_suite.py`, bead oo-gxp) for the two-arm frame-hash
differential, and scenario 012 (`tests/golden/retro_missions.py`, bead oo-3ya) for the
spec/provenance knob discipline. Both are on main.

WHY MATERIALS NEED THE FRAME, NOT JUST THE HEAP
-----------------------------------------------
Scenario 012 asks "did the expansion's SCRIPTS go live", a question about objects in a JS heap.
Materials are not in the JS heap: a `shaders`/`materials` dictionary that was parsed and merged but
never bound to a mesh leaves `worldScripts` and `Ship.shipDataForKey` looking EXACTLY the same as
one that textured a cube on screen. So this scenario measures three stages of one pipeline and
requires all three:

  parsed  ->  Ship.shipDataForKey reads the merged registry back (defence 2)
  decoded ->  [texture.upload] names each map at its real IHDR pixel size (defence 3)
  drawn   ->  the rendered frame's luminance grid moves when the maps are absent (defence 4)

WHAT THE FIXTURE ACTUALLY CONTAINS, MEASURED ON DISK
-----------------------------------------------------
`Material Test Suite.oxp` ships, and all of it was verified present rather than assumed:

  * `Config/shipdata.plist`, 25 entries: one `is_template` base plus 17 `oolite_shader_test_suite_N`
    (each carrying a `shaders` dict) and 7 `oolite_non_shader_test_suite_N` (each carrying a
    `materials` dict). Every non-base entry repeats its description in
    `script_info.oolite_material_test_suite_label`.
  * 27 PNG texture maps under `Textures/` - diffuse, emission, illumination, specular, normal,
    spec+gloss, normal+parallax - all present, unlike PNGTestSuite whose 153 suite images are NOT
    shipped (scenario 010 documents that).
  * one 2048x1024 backdrop under `Images/`.
  * one world script, `oolite-material-test-suite` version 1.3.
  * a `manifest.plist` - see below, this fixture is NOT NOMANIF.

THE EXPANSION'S OWN SUITE IS NOT DRIVEN, AND THAT IS DELIBERATE
----------------------------------------------------------------
`Scripts/oolite-material-test-suite.js` drives 24 mission screens via a chain of
`mission.runScreen(..., this.runNextTest, this)` callbacks, each of which spawns its cube with
`system.addShips(modelName, 1, system.sun.position, 10000)` - a ROLE spawn. Bead oo-izi proved a
role spawn is a RANROT draw (Universe.m:4008 -> :3948 -> OOShipRegistry.m:276-279) whose position
in the sequence depends on frames burned before it, so a fixed seed does NOT fix the cast, and the
rig advances only on a KEYPRESS this tier cannot send. Driving it would make the golden a
stopwatch.

So this scenario renders ONE pinned material configuration itself, and pins the cast the way
oo-izi prescribes: the model is named in LITERAL `[shipKey]` form
(`[oolite_shader_test_suite_13]`), which OOShipRegistry.m:1229 registers at probability 1.0, so
`newShipWithRole:` resolves it with NO draw. `spinModel: false` is equally load-bearing:
`makeDemoShipWithRole:spinning:` (Universe.m:5806-5843) calls `setDemoShip:1.0` when spinning, and
ShipEntity.m:2337-2342 then orients the model from `[UNIVERSE getTime]` - a wall-clock-driven
rotation that would make every frame different. With `spinning:NO` the rate is 0 and the branch is
not taken.

THIS FIXTURE HAS A manifest.plist - A CORRECTION TO THE NOMANIF FRAMING
------------------------------------------------------------------------
Bead oo-kcrw classified "the five in-tree legacy test-oxps" as NOMANIF. MEASURED on disk, there are
SIX in-tree test-oxps and this is the sixth:

    AI overflow test.oxp              manifest.plist absent
    JavaScript Interface Tests.oxp    manifest.plist absent
    PNGTestSuite.oxp                  manifest.plist absent
    RetroMissions.oxp                 manifest.plist absent
    Fallback test.oxp                 manifest.plist absent
    Material Test Suite.oxp           manifest.plist PRESENT  (identifier org.oolite.material-test-suite, version 1.3)

CONFIRMED BY A REAL LAUNCH, verbatim from that run's own Latest.log:

    08:45:43.288 [searchPaths.dumpAll]: Resource paths:
        C:/Users/jon/AppData/Local/Temp/oo_qd6_probe/probe-124541-p8600-10436/oxp-stage/Material Test Suite.oxp

and ZERO `[oxp-standards.error]` lines in 13452 bytes of log.

DECISION, STATED DELIBERATELY: this scenario allow-lists NOTHING. `allowed_oxp_standards_errors`
is 0 and the allow-list is EMPTY, so ANY `[oxp-standards.error]` line fails the run. No manifest is
staged because the fixture already has one; fabricating or removing content would falsify the thing
under test. This is STRICTER than 010/012's exact-count allowance, not weaker - and it is the right
predicate precisely because the engine has nothing to complain about here. (The count is still
pinned as a number and asserted, so a future change that starts emitting a standards error is a
red, not a shrug.)

THE FRAME DIFFERENTIAL, MEASURED - AND THE MATERIAL IS THE VARIABLE
--------------------------------------------------------------------
Against bead oo-ae9's instrument (`tests/golden/frame_hash.py`, tolerance 0.004377 derived from a
measured noise floor of 0.002541 and a weakest real signal of 0.007541, USED AS MEASURED):

    same scene, two separate launches      d = 0.000538    0.12x tolerance   (A vs B)
    OXP ABSENT entirely                    d = 0.210554   48.10x tolerance   (A vs C)
    OXP PRESENT but NO TEXTURED MODEL      d = 0.072389   16.54x tolerance   (A vs D)

The third arm is the one that matters, and it is NARROWER than "remove the OXP". Arm D stages the
expansion, opens the same mission screen with the same backdrop, and differs from the blessed run
ONLY in that no material-bearing model is displayed. Its texture-upload list independently records
the backdrop alone - the two `oolite_shader_test_suite_*` maps are simply never decoded. So the
16.5x movement is attributable to THE MATERIAL MAPS specifically, not to the expansion's mere
presence. A 134-fold separation between noise (0.12x) and that signal (16.54x).

MEASURED ANSWER TO THE QUESTION THE BRIEF ASKS: yes, materials move the frame hash, far beyond the
instrument's noise, and they do so even when every other thing about the run is held constant.

WHY A DEAD RUN CANNOT SATISFY THIS
-----------------------------------
Each defence below is POSITIVE - something had to happen for the field to hold its value - and
every one is EMITTED BY THE ENGINE rather than inferred by this script:

  1. `oxp_world_scripts` / `oxp_script_versions`: a name in the running game's `worldScripts` that
     a stock game lacks, and a property read off the live object. Stock baseline MEASURED by the
     `--no-oxp` control, not guessed.
  2. `material_shipdata_entries` (24) + `material_map_sample`: `Ship.shipDataForKey` (OOJSShip.m)
     reads the MERGED registry; the sample carries the actual map filenames and labels read back
     out of the running engine.
  3. `material_texture_uploads`: `[texture.upload]` is emitted by OOConcreteTexture -upload
     (OOConcreteTexture.m:525) and is reached ONLY after the PNG loader decoded the file - it bails
     at `texture.load.png.failed` long before any upload. Each recorded width/height is checked
     against the IHDR chunk read off the STAGED FILE by this module (bead oo-vwd's derive-and-pin
     rule), AND against a literal in spec.json.
  4. `display_model_key` / `display_model_label`: `mission.displayModel` is the ShipEntity the
     ENGINE constructed for the screen (OOJSMission.m:660-665); reading `.dataKey` and
     `.scriptInfo.oolite_material_test_suite_label` off it proves the pinned entry - not some other
     ship - is the thing being drawn.
  5. THE FRAME, compared with the measured tolerance against the stored grid.

A run in which the material dictionaries silently applied nothing has an EMPTY upload list for the
maps, a `display_model_key` of "NONE", and a frame 16x the tolerance away. None of those is
distinguishable from success by "the log was clean" or by rc=0.

THE FRAME GRID IS NOT IN THE CANONICAL DUMP, DELIBERATELY
----------------------------------------------------------
llvmpipe is not bit-reproducible across runs (oo-ae9: 0 of 3 same-scene pairs byte-identical), so a
frame hash inside state.json would fail the byte-identical golden comparison every run. The grid
lives BESIDE the dump as `frame.grid` (4096 raw bytes) and is compared with the TOLERANCE, while
state.json stays byte-exact. Two artifacts, two comparison rules.

DETERMINISM AND ISOLATION
-------------------------
As 010, for the same measured reasons: a reserved port plus a debugConfig.plist in a private
OO_ADDITIONALADDONSDIRS (the game DIALS OUT to the port named there, OODebugSupport.m:67-80 - a run
on the shared 8563 can be captured and quit by a sibling's console while still exiting rc=0, bead
oo-het); all THREE traffic sources switched off before any slow probe (system populator, each
station's own `hasNPCTraffic` schedule at StationEntity.m:960-995, and oolite-populator.js's
`systemWillRepopulate` whose station picker ends in an unconditional `return system.mainStation`);
the world driven to a FIXED POINT immediately before the measurement; the tick budget measured on
the GAME clock. The world is not `pauseGame()`d because GlobalPauseGame (OOJSGlobal.m:831-856)
returns NO on a mission screen - quiescence is demonstrated directly instead.
"""

import argparse
import json
import os
import re
import shutil
import struct
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
from state_dump import dump_state, ensure_launchable, start_with_retry  # noqa: E402

SCENARIO = "008-material-test-suite"

# The spec and golden live under the guarded goldens/ tree once Jon has approved the protected-path
# addition (tools/rebless-approvals.txt). Until then they are staged under tests/golden/pending/,
# and BOTH locations are searched so landing them is a pure `git mv` with no code change - exactly
# scenarios 010 and 012's arrangement. See tests/golden/pending/008-material-test-suite/LANDING.md.
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
FRAME_SETTLE_SECONDS = 3.0
SETTLE_TIMEOUT_SECONDS = 120
# How many clear-recount-and-remeasure rounds `quiesce` spends looking for a clean one. MEASURED:
# with all three traffic sources off the world converges in 1-3 rounds; 20 is a ceiling whose only
# job is to turn "never settles" into a loud refusal rather than a hang.
CLEAR_ROUNDS = 20

OXP_STANDARDS_RE = re.compile(r"\[oxp-standards\.error\]:\s*(.*)")
# OOConcreteTexture.m:525 -- "Uploaded texture %u (%ux%u pixels, %@)". The GL texture NAME is
# deliberately dropped when normalising (an allocation artifact); the KEY and the PIXEL DIMENSIONS
# carry the evidence.
TEXTURE_UPLOAD_RE = re.compile(
    r"\[texture\.upload\]:\s*Uploaded texture \d+ \((\d+)x(\d+) pixels, ([^)]*)\)")

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


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


def png_ihdr_dimensions(path):
    """(width, height) read straight out of the file's IHDR chunk.

    THE POINT: the dimensions the gate checks against are not a literal somebody typed, they are
    read from the same bytes the engine decoded. If the engine reports uploading a texture of a
    different size than the file on disk is, the run refuses - which is what makes
    `[texture.upload]` evidence OF THESE IMAGES rather than of some texture. A literal is ALSO kept
    in spec.json so a broken derivation cannot quietly redefine the test (bead oo-vwd).
    """
    with open(path, "rb") as handle:
        head = handle.read(26)
    if len(head) < 26 or head[:8] != PNG_SIGNATURE:
        raise ScenarioError(
            "%s is not a PNG (signature %r); this scenario's texture evidence is about PNG "
            "material maps and there is nothing here to decode" % (path, head[:8]))
    if head[12:16] != b"IHDR":
        raise ScenarioError("%s has no IHDR as its first chunk (%r)" % (path, head[12:16]))
    width, height = struct.unpack(">II", head[16:24])
    return int(width), int(height)


def staged_map_dimensions(staged_oxp, spec):
    """IHDR dimensions of every texture this scenario expects the engine to upload."""
    out = {}
    for key in sorted(spec["expected_texture_keys"]):
        path = os.path.join(staged_oxp, *key.split("/"))
        if not os.path.isfile(path):
            raise ScenarioError(
                "the staged expansion has no %s. The scenario's material evidence is about that "
                "map; without the file there is nothing for the engine to decode and the upload "
                "assertion below would be unfalsifiable." % key)
        width, height = png_ihdr_dimensions(path)
        out[key] = [width, height]
    return out


def stage_oxp(spec, addons_dir, twice=False):
    """Copy the expansion into a private addons root and return its staged path.

    A COPY, not a junction: the game writes nothing here, but the staged root is deleted at the end
    of the run and unstage must never follow a link into the tracked tree.

    THE DIRECTORY IS CALLED `oxp-stage`, NOT `addons`, AND THAT IS LOAD-BEARING. The game also
    searches `<app dir>/../AddOns` by default and the staged app lives at `<artifact>/app`, so a
    staging directory named `<artifact>/addons` IS `<artifact>/../AddOns` on a case-insensitive
    filesystem: bead oo-3ya measured the expansion then found at TWO roots. For a NOMANIF fixture
    that showed up as four missing-manifest errors instead of two; THIS fixture has a manifest, so
    a double root shows up as a DUPLICATE-IDENTIFIER complaint instead - which is why the
    standards-error predicate here is `exactly zero, no allow-list` rather than an exact count of
    tolerated lines.

    `twice` reproduces the double-root state on purpose (--stage-double) so that predicate can be
    PROVEN to fire rather than merely asserted to be strict.
    """
    src = oxp_source(spec)
    os.makedirs(addons_dir, exist_ok=True)
    target = os.path.join(addons_dir, os.path.basename(src))
    shutil.copytree(src, target)
    if not os.path.isdir(target):
        raise ScenarioError("staging %s -> %s produced nothing" % (src, target))
    if twice:
        shutil.copytree(src, os.path.join(addons_dir, "Material Test Suite Copy.oxp"))
    return golden_run._slashes(target)


def assert_system(console, spec):
    got = console.evaluate_int("system.ID")
    if got != int(spec["system_id"]):
        raise ScenarioError(
            "scenario %s is pinned to system ID %d (%s) but the loaded save is in system ID %d; a "
            "golden taken in a different system is not comparable with the stored one"
            % (SCENARIO, int(spec["system_id"]), spec.get("system_name", "?"), got))
    return got


def assert_detail_level(console, spec):
    """Pin the renderer's detail level, and PROVE the write took.

    Load-bearing for a MATERIALS scenario specifically. `debugConsole.detailLevel` selects between
    the shader path and the fixed-function path, and the fixture ships two parallel sets of ship
    entries precisely because the two paths render differently. A run that silently fell back to
    DETAIL_LEVEL_MINIMUM would draw the same cube through a different material class and the frame
    would be beyond tolerance for a reason that has nothing to do with the expansion. So the level
    is written from the spec and READ BACK; a machine whose GL cannot reach it refuses loudly
    instead of quietly blessing a fixed-function frame as a shader one.
    """
    want = spec["detail_level"]
    console.perform("debugConsole.detailLevel = %s;" % json.dumps(want))
    got = console.evaluate("String(debugConsole.detailLevel)").strip()
    if got != want:
        raise ScenarioError(
            "debugConsole.detailLevel is %r after writing %r (this box's maximum is %r). The "
            "fixture ships separate shader and fixed-function material sets and they do not "
            "render alike, so a golden blessed at one level says nothing at the other."
            % (got, want, console.evaluate("String(debugConsole.maximumDetailLevel)").strip()))
    return got


def world_script_names(console):
    """Names of every live world script, sorted, read from the RUNNING game.

    Returned as JSON rather than as a joined string: the console transport is an XML property list
    and a separator character can be plist-escaped, silently collapsing N names into one (measured
    by bead oo-3ya).
    """
    raw = console.evaluate(
        "(function(){ var n = Object.keys(worldScripts); n.sort();"
        " return JSON.stringify(n); })()").strip()
    try:
        names = json.loads(raw)
    except ValueError as exc:
        raise ScenarioError("worldScripts did not come back as JSON (%s): %r" % (exc, raw[:200]))
    if not isinstance(names, list):
        raise ScenarioError("worldScripts came back as %r, not a list" % (names,))
    return names


def world_script_versions(console, names):
    """Split `names` into scripts resolving to a LIVE JS object and those that are bare keys."""
    live, key_only = {}, []
    for name in names:
        expr = ("(function(){ var s = worldScripts[%s];"
                " if (!s) return 'OOQD6-KEY-ONLY';"
                " return String(s.version); })()" % json.dumps(name))
        value = console.evaluate(expr).strip()
        if value == "OOQD6-KEY-ONLY":
            key_only.append(name)
        else:
            live[name] = value
    return live, sorted(key_only)


def material_shipdata(console, spec):
    """How many of the suite's material entries the merged registry resolves, plus a fixed sample.

    `Ship.shipDataForKey` reads the MERGED ship registry, so a key resolving here means the
    expansion's Config/shipdata.plist was parsed and merged into the game's own ship data.

    THE SAMPLE IS THE PART THAT IS ABOUT MATERIALS. It re-reads the material dictionary itself -
    `shaders['cube-face']` for the shader entries, `materials['cube-face']` for the fixed-function
    ones - and the `script_info.oolite_material_test_suite_label` beside it, for a FIXED set of
    keys. So the evidence names ACTUAL MAP FILENAMES from inside the running engine rather than
    counting anonymously, and a registry merged from some other expansion cannot match it.
    """
    count = console.evaluate_int(
        "(function(){ var n = 0, k = %s;"
        " for (var i = 0; i < k.length; i++) { if (Ship.shipDataForKey(k[i])) n++; }"
        " return n; })()" % json.dumps(spec["expected_shipdata_keys"]))
    sample = {}
    for key in sorted(spec["material_sample_keys"]):
        raw = console.evaluate(
            "(function(){ var d = Ship.shipDataForKey(%s);"
            " if (!d) return 'ABSENT';"
            " var m = (d.shaders && d.shaders['cube-face']) ||"
            "         (d.materials && d.materials['cube-face']);"
            " if (!m) return 'NOMATERIAL';"
            " var keys = []; for (var p in m) keys.push(p); keys.sort();"
            " return JSON.stringify([keys,"
            "   String(d.script_info && d.script_info.oolite_material_test_suite_label)]); })()"
            % json.dumps(key)).strip()
        if raw == "ABSENT":
            raise ScenarioError(
                "Ship.shipDataForKey(%r) is absent from the merged ship registry: the expansion's "
                "shipdata.plist was not merged, so nothing defines a material to apply" % key)
        if raw == "NOMATERIAL":
            raise ScenarioError(
                "ship entry %r resolved but carries NEITHER a shaders['cube-face'] NOR a "
                "materials['cube-face'] dictionary. The entry exists but its MATERIAL - the whole "
                "subject of this scenario - did not survive the merge. This is exactly the silent "
                "half-failure a key count alone cannot see." % key)
        try:
            props, label = json.loads(raw)
        except ValueError as exc:
            raise ScenarioError("material sample %r came back unparseable (%s): %r"
                                % (key, exc, raw[:200]))
        sample[key] = {"material_keys": props, "label": label}
    return count, sample


def enable_log_channels(console, spec):
    """Turn on the channels this scenario's evidence is read from, and PROVE they are on.

    They are off by default: logcontrol.plist sets `$textureDebug = no` and
    `texture.upload = $textureDebug`. A run that merely ASKED for them and did not check would
    produce an empty upload list indistinguishable from a run where nothing decoded, which is
    exactly the vacuity this scenario exists to close. So every flag is read back.
    """
    channels = list(spec["log_channels"])
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
            "these log channels did not switch on: %s. The material evidence is read out of the "
            "run's own Latest.log on those channels, and with them off an empty upload list would "
            "mean 'not logged' rather than 'not decoded' - the two must not be confusable."
            % ", ".join(off))
    return channels


def suppress_populators(console):
    """Switch the system populator off at the source (copied from scenarios 001/010/012).

    `system.setPopulator(key, null)` deletes a populator setting (OOJSSystem.m:1311). The populator
    keeps adding traffic while the scenario runs and every ship it adds consumes RANROT draws, so a
    fixed seed fixes the SEQUENCE but not how far a wall-clock-timed run has got through it.
    """
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
    """Switch off EVERY station's own NPC traffic, and prove none is left on.

    THE SECOND POPULATOR. Suppressing `system.populatorSettings` is NOT sufficient: StationEntity
    -update (StationEntity.m:960-995) runs its OWN launch schedule for shuttles, traders and
    patrols, gated on `hasNPCTraffic` (:967, :979, :991) and on nothing the system populator owns.
    Bead oo-gxp measured five different dumps in ten runs with only the system populator off.
    `hasNPCTraffic` is READWRITE from JS (OOJSStation.m:123, :358-361).
    """
    remaining = console.evaluate(
        "(function(){ var e = system.stations, off = 0, on = [];"
        " for (var i = 0; i < e.length; i++) {"
        "   e[i].hasNPCTraffic = false; off++;"
        "   if (e[i].hasNPCTraffic) on.push(e[i].name); }"
        " return JSON.stringify([off, on]); })()").strip()
    try:
        count, still_on = json.loads(remaining)
    except ValueError as exc:
        raise ScenarioError("station traffic suppression came back unparseable (%s): %r"
                            % (exc, remaining[:200]))
    if still_on:
        raise ScenarioError(
            "these station(s) still report hasNPCTraffic after it was written false: %r. "
            "StationEntity -update launches shuttles, traders and patrols on its own schedule "
            "(StationEntity.m:960-995), so the world would keep gaining ships during the run and "
            "no two dumps could agree." % (still_on,))
    if not count:
        raise ScenarioError(
            "no station was found to suppress. The scenario is docked at Lave's main station by "
            "construction, so zero stations means the save did not load the world this scenario "
            "is about.")
    return count


def suppress_repopulator(console, spec):
    """Neuter the `oolite-populator` world script's REPOPULATE handler, and prove it is gone.

    THE THIRD SOURCE, AND THE ONE THAT DEFEATS THE OTHER TWO (bead oo-gxp). `setPopulator(k, null)`
    clears the settings that run when a system is first populated; `hasNPCTraffic = false` stops
    StationEntity's own schedule. Neither touches `oolite-populator.js`'s `systemWillRepopulate`
    (:1027), which the engine fires periodically for the life of the system - and whose station
    picker `_tradeStation` (:2656-2680) tests `hasNPCTraffic` in its loop but ENDS WITH an
    unconditional `return system.mainStation`, so the flag does not stop it.

    The handler names live in spec.json rather than inline, because a handler upstream renames is a
    handler this no longer suppresses; the read-back turns that into a red rather than a flaky
    golden.
    """
    quieted = []
    for name in spec["repopulator_handlers"]:
        before = console.evaluate(
            "String(typeof worldScripts['oolite-populator'][%s])" % json.dumps(name)).strip()
        if before == "undefined":
            raise ScenarioError(
                "worldScripts['oolite-populator'].%s does not exist. This scenario suppresses that "
                "handler because it launches traffic for the life of the system "
                "(oolite-populator.js:1027); if it has been renamed upstream, the suppression is "
                "silently doing nothing and the scenario is no longer deterministic. Re-derive the "
                "handler names rather than dropping this check." % name)
        console.perform(
            "worldScripts['oolite-populator'][%s] = function(){};" % json.dumps(name))
        after = console.evaluate(
            "String(worldScripts['oolite-populator'][%s].toString().replace(/\\s+/g,''))"
            % json.dumps(name)).strip()
        if "function(){}" not in after:
            raise ScenarioError(
                "worldScripts['oolite-populator'].%s did not become a no-op (it reads %r); the "
                "repopulator is still live and will keep adding ships during the run"
                % (name, after[:120]))
        quieted.append(name)
    return quieted


def clear_system(console):
    """Remove every non-player, non-station ship; report how many went and how many remain.

    THIS FUNCTION DOES NOT JUDGE. Deciding whether the world is quiet is `quiesce`'s job, because a
    single round legitimately finds ships: one the repopulator launched a moment before the
    suppression landed is still in flight, and removing it is normal, not a failure.
    """
    removed = console.evaluate_int(
        "(function(){ var ships = system.allShips, n = 0;"
        " for (var i = 0; i < ships.length; i++) {"
        "   if (!ships[i].isPlayer && !ships[i].isStation) { ships[i].remove(); n++; } }"
        " return n; })()")
    remaining = console.evaluate_int(
        "(function(){ var ships = system.allShips, n = 0;"
        " for (var i = 0; i < ships.length; i++) {"
        "   if (!ships[i].isPlayer && !ships[i].isStation) n++; }"
        " return n; })()")
    return removed, remaining


def moving_entities(console, demo_key=None):
    """Every non-player ship reporting motion, as 'name=magnitude' strings.

    `magnitude` IS A FUNCTION, NOT A PROPERTY - calling it is what makes this able to fail at all
    (bead oo-jor measured a version that compared a function OBJECT with a number, so the guard
    passed on every run including the ones that should have refused).

    `demo_key` is EXCLUDED, and that exclusion is narrow and justified rather than convenient: the
    mission screen's demo ship is constructed by the engine at a fixed offset with
    `switchAITo:"nullAI.plist"` and `CLASS_NO_DRAW` (Universe.m:5815-5835) and, with
    `spinModel:false`, `demoRate == 0` so ShipEntity.m:2337 never re-orients it. It is scenery this
    scenario deliberately put on the screen, not traffic. It is excluded BY DATA KEY, so any OTHER
    ship in motion is still a refusal.
    """
    raw = console.evaluate(
        "(function(){ var s = system.allShips, bad = [], skip = %s;"
        " for (var i = 0; i < s.length; i++) {"
        "   if (s[i].isPlayer) continue;"
        "   if (skip && String(s[i].dataKey) === skip) continue;"
        "   if (s[i].velocity.magnitude() > 0.0005)"
        "     bad.push((s[i].shipUniqueName || s[i].name) + '=' +"
        "              s[i].velocity.magnitude().toFixed(4)); }"
        " return bad.join(', '); })()" % json.dumps(demo_key)).strip()
    return [part for part in raw.split(", ") if part]


def quiesce(console, rounds=CLEAR_ROUNDS, demo_key=None):
    """Clear AND settle as ONE fixed point, and refuse if the world never reaches it.

    THE ORDER OF THE LAST FEW SECONDS IS THE WHOLE PROBLEM (bead oo-gxp). Clearing to a fixed point
    and THEN switching screens, settling and snapshotting leaves several seconds in which a ship
    can arrive. So the two conditions are checked TOGETHER, in one loop, immediately before the
    measurement: a round passes only when it removes nothing, sees nothing, AND every remaining
    entity reports zero motion. Anything less is "the world was quiet a moment ago", which is not a
    claim this scenario can make.
    """
    history = []
    for _ in range(rounds):
        removed, remaining = clear_system(console)
        moving = moving_entities(console, demo_key)
        history.append([removed, remaining, len(moving)])
        if removed == 0 and remaining == 0 and not moving:
            return history
        time.sleep(0.3)
    raise ScenarioError(
        "the world never went quiet: %d rounds went %r ([removed, remaining, moving] per round) "
        "and none was clean. The three known sources are the system populator, each station's own "
        "launch schedule (StationEntity.m:960-995) and oolite-populator.js's systemWillRepopulate, "
        "and all three are switched off before this runs. A fourth source is a FINDING; do not "
        "widen the round count to paper over it." % (rounds, history))


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


def show_material_screen(console, spec, no_model=False):
    """Open the mission screen carrying the expansion's backdrop AND its material-bearing model.

    THE MODEL IS NAMED IN LITERAL `[shipKey]` FORM, AND THAT IS THE DETERMINISM FIX FROM oo-izi.
    `mission.runScreen`'s `model` goes to `makeDemoShipWithRole:` -> `newShipWithRole:`, which for
    a bare role is a RANROT draw over a probability set (Universe.m:4008 -> :3948 ->
    OOShipRegistry.m:276-279) whose position in the sequence depends on frames burned earlier - so
    a fixed seed does NOT fix which ship appears. In `[key]` form OOShipRegistry.m:1229 registers
    the key at probability 1.0, so the lookup resolves with NO draw at all.

    `spinModel: false` is the second half. `makeDemoShipWithRole:spinning:` (Universe.m:5827-5834)
    sets `demoRate` to 1.0 when spinning, and ShipEntity.m:2337-2342 then derives the model's
    orientation from `[UNIVERSE getTime]` - a wall-clock rotation that would put a different frame
    on screen every run. With spinning NO the rate is 0 and that branch is dead.

    `no_model=True` is the NARROW graphical mutant (--no-model): the SAME expansion, the SAME
    backdrop, the SAME screen - only the material-bearing model is absent. It is what makes the
    frame differential attributable to the MATERIAL MAPS rather than to the expansion's presence.
    """
    config = {
        "title": "",
        "message": "\n\n\n",
        "spinModel": False,
        "background": {"name": spec["backdrop_image"],
                       "width": int(spec["backdrop_screen_width"]),
                       "height": int(spec["backdrop_screen_height"])},
    }
    if not no_model:
        config["model"] = spec["display_model_role"]
    opened = console.evaluate(
        "(function(){ try { return String(mission.runScreen(%s)); }"
        " catch (e) { return 'ERR ' + e; } })()" % json.dumps(config)).strip()
    if opened.lower() != "true":
        raise ScenarioError(
            "mission.runScreen did not open the material screen (returned %r). Without it there is "
            "no frame carrying the expansion's materials and the graphical evidence is absent."
            % opened)
    screen = console.evaluate("guiScreen").strip()
    if screen != "GUI_SCREEN_MISSION":
        raise ScenarioError(
            "guiScreen is %r, not GUI_SCREEN_MISSION, after runScreen returned true; the frame "
            "would be of some other screen entirely" % screen)
    return screen


def read_display_model(console):
    """What the ENGINE actually put on the screen, read off `mission.displayModel`.

    OOJSMission.m:660-665 sets `mission.displayModel` to the ShipEntity the engine CONSTRUCTED for
    the screen, and deletes the property when it made none. So this is engine-emitted evidence that
    the pinned shipdata entry - and therefore its material dictionary - is the thing being drawn.
    A dead run, or one whose registry lacks the key, reads NONE.
    """
    raw = console.evaluate(
        "(function(){ var m = mission.displayModel;"
        " if (!m) return 'NONE';"
        " return JSON.stringify([String(m.dataKey),"
        "   String(m.scriptInfo && m.scriptInfo.oolite_material_test_suite_label)]); })()").strip()
    if raw == "NONE":
        return None, None
    try:
        key, label = json.loads(raw)
    except ValueError as exc:
        raise ScenarioError("mission.displayModel came back unparseable (%s): %r" % (exc, raw[:200]))
    return key, label


def capture_frame(console, artifact_dir, attempts=20):
    """Snapshot the current frame and return (png path, 64x64 luminance grid).

    THE FILE APPEARS BEFORE IT IS FINISHED. `_await_png` waits for the NAME to show up, which on
    Windows happens while the game still holds the handle open for writing - reading it then fails
    with PermissionError or, worse, reads a truncated image and hashes it as if it were the frame.
    Both are retried; a frame that never becomes readable is a REFUSAL rather than a hash of half a
    file.
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
        "the snapshot at %s never became readable (%s: %s). The game writes the file while still "
        "holding the handle, so this is retried; a frame that stays unreadable means the hash "
        "would be taken on a partial image, which is worse than no frame at all."
        % (png, type(last).__name__, last))


def normalise_oxp_error(message, oxp_basename):
    """Replace the volatile staged path with the OXP's basename.

    The staged addons root carries a timestamp, a port and a pid, so the raw message differs on
    every run by construction. Only the PATH is replaced; the rest of the message is compared
    VERBATIM.
    """
    return re.sub(r"\S*%s" % re.escape(oxp_basename), oxp_basename, message).strip()


def normalise_texture_key(key, oxp_basename):
    """`Textures/x.png:0x0007/0/0` -> `Textures/x.png`.

    The trailing fields are the texture OPTIONS mask and the anisotropy/lod settings - rendering
    configuration rather than evidence about the image. The leading path is normalised the same way
    the error signatures are, for the same reason.
    """
    key = normalise_oxp_error(key, oxp_basename)
    return key.split(":")[0].strip()


def read_log_evidence(artifact_dir, oxp_basename, spec):
    """Collect the standards, texture-upload and shader evidence from THIS run's own Latest.log."""
    log = os.path.join(artifact_dir, "Latest.log")
    if not os.path.isfile(log):
        raise ScenarioError(
            "no Latest.log at %s: the run wrote no log, so neither the standards predicate nor the "
            "material-upload evidence can be checked at all" % log)
    with open(log, "r", encoding="utf-8", errors="replace") as handle:
        text = handle.read()
    standards = [normalise_oxp_error(m.group(1), oxp_basename)
                 for m in OXP_STANDARDS_RE.finditer(text)]
    uploads = []
    for match in TEXTURE_UPLOAD_RE.finditer(text):
        width, height, key = int(match.group(1)), int(match.group(2)), match.group(3)
        uploads.append({"key": normalise_texture_key(key, oxp_basename),
                        "width": width, "height": height})
    # Shader/texture DIAGNOSTICS: any line on a failure channel this run switched on. Meaningful
    # only because the channels were read back as enabled (see enable_log_channels).
    failure_prefixes = tuple("[%s]" % c for c in spec["failure_log_channels"])
    failures = [line.strip() for line in text.splitlines()
                if any(p in line for p in failure_prefixes)]
    return standards, uploads, failures, len(text)


def assert_ran(evidence, spec):
    """The anti-vacuity gate, applied before anything is written.

    Every clause names a field the dump CARRIES, so the same property is re-checked by every future
    diff against the stored golden rather than only at capture time.
    """
    if not evidence["oxp_staged"]:
        raise ScenarioError("evidence.oxp_staged is false: nothing was staged, so this run says "
                            "nothing about the expansion")

    # --- DEFENCE 1: the expansion's world script is LIVE ---------------------------------------
    expected_names = sorted(spec["expected_oxp_world_scripts"])
    if not evidence["oxp_world_scripts"]:
        raise ScenarioError(
            "evidence.oxp_world_scripts is empty: the running game has no world script a stock "
            "game lacks, so the Material Test Suite's script was never instantiated. The OXP being "
            "on the search path is not the same as its content being live.")
    if sorted(evidence["oxp_world_scripts"]) != expected_names:
        raise ScenarioError(
            "evidence.oxp_world_scripts is %r but the spec pins %r. A golden taken against a "
            "different set of expansion scripts is not comparable with the stored one."
            % (sorted(evidence["oxp_world_scripts"]), expected_names))
    if evidence["oxp_script_versions"] != spec["expected_live_script_versions"]:
        raise ScenarioError(
            "evidence.oxp_script_versions is %r but the spec pins %r. This is the read that proves "
            "a script FILE was found, compiled and instantiated - a name in oxp_world_scripts only "
            "proves the world-scripts list was merged."
            % (evidence["oxp_script_versions"], spec["expected_live_script_versions"]))

    # --- DEFENCE 2: the material definitions were PARSED AND MERGED ----------------------------
    want_entries = len(spec["expected_shipdata_keys"])
    if evidence["material_shipdata_entries"] != want_entries:
        raise ScenarioError(
            "evidence.material_shipdata_entries is %r but the fixture defines exactly %d "
            "material-bearing ship entries in Config/shipdata.plist (17 shader + 7 "
            "fixed-function). Fewer means the plist was not merged, or was merged partially; more "
            "means something else is contributing these keys."
            % (evidence["material_shipdata_entries"], want_entries))
    if evidence["material_map_sample"] != spec["expected_material_sample"]:
        raise ScenarioError(
            "evidence.material_map_sample is %r but the spec pins %r. These are the MATERIAL "
            "DICTIONARIES themselves - the property names inside shaders['cube-face'] / "
            "materials['cube-face'] and the fixture's own label - read back out of the RUNNING "
            "engine's merged registry. A mismatch means the merged registry is not this fixture's, "
            "or its materials did not survive the merge."
            % (evidence["material_map_sample"], spec["expected_material_sample"]))

    # --- DEFENCE 3: the material maps were DECODED and UPLOADED --------------------------------
    uploads = evidence["material_texture_uploads"]
    if not uploads:
        raise ScenarioError(
            "evidence.material_texture_uploads is EMPTY: not one [texture.upload] line was "
            "recorded. OOConcreteTexture -upload (OOConcreteTexture.m:525) is reached only after "
            "the PNG loader has decoded the file, so an empty list means NOTHING WAS DECODED.")
    by_key = {u["key"]: u for u in uploads}
    for key in sorted(spec["expected_texture_keys"]):
        if key not in by_key:
            raise ScenarioError(
                "no [texture.upload] line named %r. That map is part of the material this "
                "scenario draws, and an unuploaded map is a material that did not go live - the "
                "silent failure a clean log and a quiet dump cannot distinguish from success. "
                "Uploads seen: %r" % (key, sorted(by_key)))
    ihdr = evidence["material_map_ihdr"]
    for key in sorted(spec["expected_texture_keys"]):
        upload, want = by_key[key], ihdr.get(key)
        if want is None:
            raise ScenarioError(
                "evidence.material_map_ihdr carries no entry for %r, so the engine's upload line "
                "for it is unchecked against the file on disk" % key)
        if [upload["width"], upload["height"]] != list(want):
            raise ScenarioError(
                "the engine reports uploading %r at %dx%d pixels, but the IHDR chunk of the staged "
                "file says %dx%d. The dimensions are read from the same bytes the engine decoded, "
                "so a disagreement means the upload is not of this image."
                % (key, upload["width"], upload["height"], want[0], want[1]))
    if ihdr != spec["expected_ihdr_dimensions"]:
        raise ScenarioError(
            "the staged maps' IHDR dimensions are %r but the spec pins %r. Both are kept on "
            "purpose: the derivation keeps the gate honest if the fixture is replaced, and the "
            "literal keeps the derivation honest if the IHDR parse silently reads the wrong bytes "
            "(bead oo-vwd)." % (ihdr, spec["expected_ihdr_dimensions"]))
    if evidence["texture_load_failures"]:
        raise ScenarioError(
            "the run emitted texture/shader loader diagnostics: %r. A materials scenario must not "
            "tolerate them - a map that failed to load is a material that did not go live."
            % (evidence["texture_load_failures"],))

    # --- DEFENCE 4: the ENGINE put the material-bearing model on the screen --------------------
    if evidence["display_model_key"] != spec["expected_display_model_key"]:
        raise ScenarioError(
            "evidence.display_model_key is %r but the spec pins %r. mission.displayModel is the "
            "ShipEntity the ENGINE constructed for this screen (OOJSMission.m:660-665); a value of "
            "None means it made none, and a different key means some other ship - and therefore "
            "some other material - is what was drawn."
            % (evidence["display_model_key"], spec["expected_display_model_key"]))
    if evidence["display_model_label"] != spec["expected_display_model_label"]:
        raise ScenarioError(
            "evidence.display_model_label is %r but the spec pins %r. The label is read off the "
            "LIVE entity's scriptInfo and exists only inside the expansion's own shipdata.plist."
            % (evidence["display_model_label"], spec["expected_display_model_label"]))
    if evidence["gui_screen"] != "GUI_SCREEN_MISSION":
        raise ScenarioError(
            "evidence.gui_screen is %r: the frame was not taken on the mission screen that carries "
            "the expansion's materials" % (evidence["gui_screen"],))
    if evidence["detail_level"] != spec["detail_level"]:
        raise ScenarioError(
            "evidence.detail_level is %r but the spec pins %r. The fixture ships separate shader "
            "and fixed-function material sets and they do not render alike, so a golden blessed at "
            "one level says nothing at the other."
            % (evidence["detail_level"], spec["detail_level"]))

    # --- DEFENCE 5: the run really ran, in a world that was standing still ---------------------
    if not evidence["tick_budget_met"]:
        raise ScenarioError(
            "evidence.tick_budget_met is false: the game clock advanced less than the scenario's "
            "budget of %.3f game seconds (%d ticks), so the simulation did not run"
            % (evidence["game_seconds_budget"], evidence["ticks"]))
    if not evidence["world_reached_fixed_point"]:
        raise ScenarioError(
            "evidence.world_reached_fixed_point is false: the clearing loop never saw a round that "
            "both removed nothing and left nothing, so something was still adding entities when "
            "the dump was taken and no two runs can agree")
    if not evidence["populators_suppressed"]:
        raise ScenarioError(
            "evidence.populators_suppressed is 0: the system populator was never switched off, so "
            "the world kept gaining traffic during the run and no two dumps can agree")
    if not evidence["stations_quieted"]:
        raise ScenarioError(
            "evidence.stations_quieted is 0: no station had hasNPCTraffic written false. "
            "StationEntity -update (StationEntity.m:960-995) runs its OWN launch schedule "
            "independently of the system populator.")
    if sorted(evidence["repopulator_handlers_quieted"]) != sorted(spec["repopulator_handlers"]):
        raise ScenarioError(
            "evidence.repopulator_handlers_quieted is %r but the spec pins %r. "
            "oolite-populator.js's systemWillRepopulate keeps launching traffic for the life of "
            "the system, and hasNPCTraffic does not stop it because its station picker ends with "
            "an unconditional `return system.mainStation`."
            % (sorted(evidence["repopulator_handlers_quieted"]),
               sorted(spec["repopulator_handlers"])))
    if not evidence["player_docked"]:
        raise ScenarioError(
            "evidence.player_docked is false. This scenario's frame is a station mission screen; "
            "undocked, the camera is wherever the ship drifted to and the frame hash is noise.")

    # --- DEFENCE 6: the standards predicate, held at EXACTLY ZERO ------------------------------
    # This fixture SHIPS a manifest.plist (verified on disk and by a real launch: 0 lines in 13452
    # bytes of log), so unlike the five NOMANIF fixtures there is nothing to tolerate. The
    # allow-list is EMPTY and the count is 0 - a strictly stronger predicate than an exact-count
    # allowance, and a deliberate choice over staging or removing content the fixture defines.
    allowed_count = int(spec["allowed_oxp_standards_errors"])
    allowed = set(spec["allowed_oxp_standards_error_signatures"])
    if evidence["oxp_standards_errors"] != allowed_count:
        raise ScenarioError(
            "evidence.oxp_standards_errors is %d but exactly %d is allowed. This fixture SHIPS a "
            "manifest.plist (identifier org.oolite.material-test-suite, version 1.3), so unlike "
            "the five NOMANIF fixtures bead oo-kcrw classified there is nothing here to tolerate: "
            "any such line is a NEW problem. Widening this number to make a run pass is forbidden. "
            "Signatures seen: %r"
            % (evidence["oxp_standards_errors"], allowed_count,
               evidence["oxp_standards_error_signatures"]))
    unexpected = [s for s in evidence["oxp_standards_error_signatures"] if s not in allowed]
    if unexpected:
        raise ScenarioError(
            "the run emitted [oxp-standards.error] line(s) %r. The allow-list for this fixture is "
            "EMPTY by design - it has a manifest - so any such line is a finding, not noise."
            % (unexpected,))


def canonical(obj):
    """The one serialisation used for the golden, for a fresh run, and for the hash."""
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def run(app_dir, out_path, spec, run_root, keep=False, stage=True, empty_stage=False,
        stage_double=False, no_model=False, seed_override=None, ticks_override=None,
        frame_out=None):
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

    # `empty_stage` is the NARROW staging mutant: the staging root exists and is on
    # OO_ADDITIONALADDONSDIRS, but the expansion has been removed from it. Narrower than --no-oxp
    # on purpose - oxp_staged stays true, so the run gets past the staging assertion and trips the
    # assertion actually under test. A mutant applied ABOVE the assertion you mean to exercise
    # short-circuits it (bead oo-vwd).
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

            # SUPPRESSION FIRST, BEFORE ANY SLOW PROBE. The shipdata probe below makes ~30 console
            # round trips and burns several seconds of GAME time, during which a station with
            # hasNPCTraffic still on launches traders and miners; bead oo-gxp measured eight of ten
            # runs refusing when the suppression came after the probe. Order is load-bearing.
            channels = enable_log_channels(console, spec)
            detail = assert_detail_level(console, spec)
            suppressed = suppress_populators(console)
            stations_quieted = suppress_station_traffic(console)
            repopulator_handlers = suppress_repopulator(console, spec)
            quiesce(console)

            names = world_script_names(console)
            stock = set(spec["stock_world_scripts"])
            oxp_names = sorted(n for n in names if n not in stock)
            versions, key_only = world_script_versions(console, oxp_names)
            shipdata_entries, material_sample = (0, {})
            if oxp_names:
                shipdata_entries, material_sample = material_shipdata(console, spec)

            elapsed = run_ticks(console, ticks, float(spec["tick_seconds"]))

            # SCREEN FIRST, THEN QUIESCE, THEN MEASURE - the order is load-bearing (bead oo-gxp):
            # clearing to a fixed point and THEN switching screens leaves seconds in which a ship
            # can arrive. So the screen is opened and settled first, and the world is driven to its
            # fixed point LAST, immediately before the frame and the dump.
            gui_screen = show_material_screen(console, spec, no_model=no_model)
            settle(console)
            model_key, model_label = read_display_model(console)
            clear_rounds = quiesce(console, demo_key=model_key)
            player_docked = console.evaluate("String(player.ship.docked)").strip().lower() == "true"
            png, grid = capture_frame(console, artifact_dir)
            state = json.loads(dump_state(console))

        # AFTER the game has exited, so the log is complete and flushed.
        standards, uploads, failures, log_bytes = read_log_evidence(
            artifact_dir, oxp_basename, spec)

        ihdr = {}
        if staged_oxp:
            ihdr = staged_map_dimensions(staged_oxp, spec)

        evidence = {
            "scenario": SCENARIO,
            "oxp_staged": bool(stage or empty_stage),
            "oxp_basename": oxp_basename,
            "oxp_world_scripts": oxp_names,
            "oxp_script_versions": versions,
            "oxp_key_only_scripts": key_only,
            "material_shipdata_entries": shipdata_entries,
            "material_map_sample": material_sample,
            "material_texture_uploads": sorted(
                uploads, key=lambda u: (u["key"], u["width"], u["height"])),
            "material_map_ihdr": ihdr,
            "texture_load_failures": failures,
            "log_channels": sorted(channels),
            "display_model_key": model_key,
            "display_model_label": model_label,
            "detail_level": detail,
            "oxp_standards_errors": len(standards),
            "oxp_standards_error_signatures": sorted(set(standards)),
            "gui_screen": gui_screen,
            "player_docked": player_docked,
            # The BUDGET is pinned; the MEASURED elapsed time is deliberately NOT in the dump - the
            # overshoot past the 100 ms poll is a property of how fast this box rendered that
            # interval, not of the engine (bead oo-jor). The assertion keeps full strength as a
            # boolean and the raw float is reported on stdout by the CLI.
            "tick_budget_met": bool(elapsed >= ticks * float(spec["tick_seconds"])),
            "game_seconds_budget": round(ticks * float(spec["tick_seconds"]), 3),
            "ticks": ticks,
            "seed": seed,
            "system_id": int(spec["system_id"]),
            "populators_suppressed": len(suppressed),
            "stations_quieted": stations_quieted,
            "repopulator_handlers_quieted": sorted(repopulator_handlers),
            # The NUMBER of rounds is deliberately NOT in the dump - it depends on how far the
            # station's launch queue had drained, which is a stopwatch reading. What IS recorded is
            # that the world reached a fixed point at all.
            "world_reached_fixed_point": bool(clear_rounds) and clear_rounds[-1] == [0, 0, 0],
        }
        # THE FRAME IS WRITTEN BEFORE THE GATE, THE DUMP ONLY AFTER IT. This ordering is
        # deliberate and is what makes the control arm measurable. `--no-model` is a run whose
        # material maps never reach the screen: it MUST refuse to dump (and it does, naming the
        # missing specular upload), but its FRAME is exactly the artifact the differential needs.
        # Writing the grid first means the control can be measured with THIS code rather than with
        # a hand-rolled copy of it. The dump - the thing a golden comparison consumes - is still
        # written only after every assertion passed, so a refused run leaves no dump behind.
        if frame_out:
            parent = os.path.dirname(os.path.abspath(frame_out))
            if parent:
                os.makedirs(parent, exist_ok=True)
            with open(frame_out, "wb") as handle:
                handle.write(bytes(grid))
        assert_ran(evidence, spec)
        state["evidence"] = evidence
        text = canonical(state)
        if out_path:
            parent = os.path.dirname(os.path.abspath(out_path))
            if parent:
                os.makedirs(parent, exist_ok=True)
            with open(out_path, "w", encoding="utf-8", newline="\n") as handle:
                handle.write(text)
        return {"ok": True, "out": out_path, "frame_out": frame_out, "port": port,
                "staged_oxp": staged_oxp, "png": golden_run._slashes(png),
                "frame_hash": frame_hash.hex_digest(grid),
                "wall_seconds": round(time.time() - started, 1), "bytes": len(text),
                "log_bytes": log_bytes, "game_seconds_elapsed": round(elapsed, 3),
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
    """Compare a captured grid with the stored reference under the MEASURED tolerance.

    `tol` defaults to `frame_hash.derive_tolerance()` - bead oo-ae9's measurement over
    calibration.json. It is NEVER adjusted to make a run pass; if the renderer genuinely changed,
    re-measure with calibrate.py and re-bless.
    """
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
    parser = argparse.ArgumentParser(prog="tests/golden/material_test_suite.py",
                                     description=__doc__.split("\n")[0])
    parser.add_argument("--app-dir", default=None)
    parser.add_argument("--out", default=None, help="write the canonical dump here")
    parser.add_argument("--frame-out", default=None, help="write the 64x64 luminance grid here")
    parser.add_argument("--run-root", default=None, help="scratch root for staged apps/artifacts")
    parser.add_argument("--keep", action="store_true")
    parser.add_argument("--seed", type=int, default=None, help="override the spec's seed")
    parser.add_argument("--ticks", type=int, default=None, help="override the spec's tick count")
    parser.add_argument("--empty-stage", action="store_true",
                        help="MUTANT: create the staging directory but REMOVE the expansion from "
                             "it. Narrower than --no-oxp: the run reaches and trips the "
                             "expansion-content evidence assertion rather than the staging one.")
    parser.add_argument("--stage-double", action="store_true",
                        help="MUTANT: stage the expansion at TWO paths, reproducing the "
                             "case-insensitive double-root state bead oo-3ya measured. Must trip "
                             "the zero-standards-error predicate.")
    parser.add_argument("--no-model", action="store_true",
                        help="MUTANT: open the identical screen with the identical backdrop but "
                             "NO material-bearing model. The narrow graphical control: the only "
                             "variable is whether the expansion's material maps reach the screen.")
    parser.add_argument("--no-oxp", action="store_true",
                        help="MUTANT: stage no expansion. The run must then FAIL its own evidence "
                             "assertions; used to prove the gate can go red, and to MEASURE the "
                             "stock world-script baseline pinned in spec.json.")
    parser.add_argument("--compare-frame", nargs=2, metavar=("GRID", "REFERENCE"),
                        help="offline: compare two stored grids and exit 0/1")
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
        os.environ.get("LOCALAPPDATA", os.path.expanduser("~")), "Temp", "oo_qd6_runs")
    run_root = golden_run._slashes(os.path.abspath(run_root))

    try:
        result = run(app_dir, args.out, spec, run_root, keep=args.keep,
                     stage=not (args.no_oxp or args.empty_stage),
                     empty_stage=args.empty_stage, stage_double=args.stage_double,
                     no_model=args.no_model,
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
